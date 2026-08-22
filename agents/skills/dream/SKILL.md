---
name: dream
description: Mine session logs for recurring process lessons and proposed instruction edits.
disable-model-invocation: true
---

# dream

Offline audit over past sessions to keep the current repo's instructions
aligned with how Anders actually works. This is **not** a memory store. It edits
the authored docs you control: `CLAUDE.md`, `AGENTS.md`, `docs/`
meta-instructions, and repo skills. It runs as a map → reduce → review → apply
pipeline and is safe to schedule weekly.

The audit contract for what counts as a learning, evidence standards, dedup
keys, and the memory/instruction/narrative boundary lives in
[`PRINCIPLES.md`](PRINCIPLES.md). Scanners and the reducer follow it.

Two domains, both first-class:

- **meta.** How we work: orchestration, parallelization, goal framing,
  verification rigor, when to ask vs act, speed/altitude, pushback calibration,
  tooling.
- **project.** Domain specifics: data conventions, app architecture, recurring
  gotchas of the repo being mined.

## Layout

- Code: this global skill folder, containing `SKILL.md`, `PRINCIPLES.md`,
  `extract.jq`, `scripts/dream.sh`, and `lib/`.
- Runtime root: `.agents/dreams/` at the root of the repo being mined. Do not
  create or use `.dream/` or the legacy `.dreams/` root.
- Review artifacts: `.agents/dreams/proposals/<run_id>/`, containing
  `proposal.md`, `proposed-changes.json`, and `decisions.json` for human review.
- Committed durable audit trail under `.agents/dreams/`: state, ledger,
  suppressions, run shards, raw findings, and review proposals.
- Ignored local config/cache under `.agents/dreams/config.local.json` and
  `.agents/dreams/cache/`: machine-specific paths/model settings and extracted
  transcripts, which are regenerable from `~/.codex`.

Deterministic work is in `scripts/dream.sh`; the agent-driven steps for spawning
scanners, running the reducer, and applying approved diffs are below.

## Run the pipeline

Let `DREAM=<this skill dir>/scripts/dream.sh`. Resolve it via the skill folder
you are reading and run it from inside the target repo. It roots itself with
`git rev-parse --show-toplevel`.

### 1. Prepare (deterministic)

```bash
bash "$DREAM" prepare            # all unprocessed sessions for this repo (incremental)
bash "$DREAM" prepare --limit 8 --recent   # pilot: 8 most recent
bash "$DREAM" prepare --full     # re-extract & re-scan everything (after extractor changes)
```

For ad hoc Dream runs, confirm and preserve the intended scope before launching
broad prepare/scan work. If Anders asks for a bounded window, specific run id,
or pilot slice, build the run around that scope and do not mix it with older
open ledger findings unless he explicitly asks for full-ledger clustering. If a
broad run was already started and Anders narrows the scope, discard the broad
reducer context and produce the scoped run's artifacts only.

Prints `RUN_DIR=...`, `REVIEW_DIR=...`, and the shard breakdown. `RUN_DIR` holds
raw scan inputs/findings. `REVIEW_DIR` is the human review folder under
`.agents/dreams/proposals/<run_id>/`. Each `shard-NN.files` lists the extracted
transcript paths for one scanner. Extraction (`extract.jq`) keeps only genuine
dialogue. It strips Codex's synthetic user-role envelopes (goal-loop prompts,
delegation/heartbeat/skill wrappers, the AGENTS.md dump), which were the bulk of
large-session bytes, keeps every user turn in full, and caps long assistant
turns. Sessions longer than `chunk_lines` are split (`chunk.py`) into overlapping
page-files so every file fits a single read. A session's chunks pack contiguously,
so only a genuine monster session spans more than one scanner. Sharding is by
token budget (`scanner_token_budget` in local
`.agents/dreams/config.local.json`): tiny sessions batch together, large ones get
their own shard(s), so scanners read deeply without blowing context.

### 2. Scan (parallel subagents, one per shard)

The original transcript is primary evidence. Historical reflections or
summaries may help locate evidence, but scanners must verify every proposed
learning against the dialogue.

Read `lib/scanner-prompt.md` and `lib/schema.md`. For **each** `shard-NN.files`
in the run dir, spawn ONE subagent using the model in `manifest.json`
(`scanner_model`). Give each subagent:

- the scanner prompt (`lib/scanner-prompt.md`) and schema (`lib/schema.md`),
- the list of transcript files in its shard (read them all, in full),
- its output path: `<RUN_DIR>/findings-shard-NN.json`.

**Fan out as wide as your harness allows. There is no fixed cap.** Spawn every
shard's scanner concurrently. If the harness limits in-flight subagents, it
will queue them, so launch them all and let it schedule. Do not throttle to an
arbitrary number. More shards in parallel means a faster run, and the shards are
independent.

Each scanner writes a JSON array of findings (or `[]`). Scanners work **blind to
each other** by design and do not dedup or rank. They emit every genuine
observation from their own shard at honest confidence. Detecting that a pattern
recurs *across* shards is the reducer's job (step 4), not theirs.

### 3. Collect (deterministic)

```bash
bash "$DREAM" collect "<RUN_DIR>"
```

Merges shard findings → `findings.json`, appends them to `ledger.jsonl` with
`finding_id`, `fingerprint`, `evidence_key`, and `status:open`, and marks the
run's sessions processed. Valid ledger statuses are only `open`, `proposed`,
`applied`, `dismissed`, and `deferred`.

### 4. Reduce (one subagent)

Read `lib/reducer-prompt.md`. Spawn ONE subagent with the `reducer_model`. This
is the only stage with the global view. **Cross-session pattern detection happens
here.** The reducer:

- clusters findings semantically across the **full open ledger**, so frequency
  weighting reflects all history;
- applies a **slight recency tilt** because Anders' work style evolves, using
  `recency_half_life_days` from `.agents/dreams/config.local.json` and leaning on
  it more for meta findings than project findings;
- may grep the transcript cache to quantify a pattern's true spread;
- reads local `suppressions.jsonl` and the current instructions;
- counts recurrence by independent evidence rather than raw session count;
- writes `<REVIEW_DIR>/proposal.md`, the compressed, ranked, human-review artifact
  with the meta section first, then project, plus a consolidation/deletions
  subsection;
- writes `<REVIEW_DIR>/proposed-changes.json`, the machine-applyable mirror.

Then run:

```bash
bash "$DREAM" mark-proposed "<RUN_DIR>"
```

This marks the proposed `finding_id` values as `status:proposed` so review-pending
items do not reappear as fresh open evidence in the next reducer pass.

### 5. Review (human gate, always)

Present `<REVIEW_DIR>/proposal.md` to Anders. Collect per-item decisions
(apply / dismiss / defer) by item id (M1, P3, ...). Write
`<REVIEW_DIR>/decisions.json`:
`[{id, finding_ids, decision, fingerprint, reason}]`, where `decision` is one of
`applied`, `dismissed`, or `deferred`. Never apply without this.

### 6. Apply (auto, approved items only)

For each `applied` item in `<REVIEW_DIR>/decisions.json`, make the edit to its
target file (`current_text` → `proposed_text`, or insert/delete). Respect repo
rules. Edits to `docs/`, `AGENTS.md`, and `CLAUDE.md` are exactly what Anders
approved here, so apply them faithfully. Do not freelance beyond the approved
text. Mark applied findings `status:applied` in the local ledger using stable
`finding_id` values from `proposed-changes.json`.

### 7. Finalize (deterministic)

```bash
bash "$DREAM" finalize "<RUN_DIR>"
```

Records dismissed patterns as suppressions so they never resurface and stamps
`last_run`. It also normalizes ledger statuses to the strict enum and applies
`decisions.json` statuses to matching `finding_id` values. Report what was
applied and where.

## Scheduling

The skill is invocable as `/dream`. For a weekly cadence, use the harness's
scheduling mechanism, such as the `schedule` skill where available. Run
`prepare → scan → collect → reduce` and leave `proposal.md` waiting in
`.agents/dreams/proposals/<run_id>/` for Monday review. Apply + finalize stay
human-gated. The pipeline is incremental, so weekly runs are cheap.

## Status

```bash
bash "$DREAM" status   # last_run, discovered / processed / pending sessions, open items
```

## Notes

- Findings that are not doc-fixable, such as model limits, one-offs, or Anders
  changing his mind, are still logged but excluded from proposals. They remain
  useful signal.
- Every run should look for what to delete or merge, not just what to add. A
  bloated CLAUDE.md aligns the agent less, not more.
- Keep committed Dream state portable. `state.json` stores durable run state such
  as `last_run` and processed session IDs. Absolute filesystem paths and local
  model/token settings belong only in ignored `.agents/dreams/config.local.json`.
