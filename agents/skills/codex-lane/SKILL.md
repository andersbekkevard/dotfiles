---
name: codex-lane
description: Dispatch, supervise, harvest, and recover detached background codex exec lanes. Use whenever running codex work in the background, running multi-lane waves, polling lane liveness, or recovering a dead/hung/quota-blocked lane.
---

# Codex Lane — detached background codex lifecycle

A lane is one detached `codex exec` run with a prompt file, a log, and a
deliverable. This lifecycle was battle-tested across 624 dispatches in the
2026-07 models-rewrite marathon; every rule below traces to a real failure
(see `.agents/reflections/2026-07-06-prd-marathon-endgame/codex-lane-failures.md`).

## Dispatch

1. Write a fully self-contained prompt to `/tmp/<lane>.md` **with the Write
   tool or a quoted heredoc (`<<'EOF'`)** — an unquoted heredoc executes any
   `$(...)` inside the prompt text while staging it. The prompt names:
   - exact cwd and allowed edit paths;
   - forbidden paths (shared crates, harness, goldens) and forbidden
     satisfactions (deleting checks, punching computed rows, loosening
     tolerances, `git checkout/restore/stash`, committing);
   - verification commands the lane must run;
   - the deliverable: an exact output file path or an exact report format;
   - "No commit/push" — the owner commits.
2. Dispatch detached:

```bash
(setsid codex exec "$(cat /tmp/<lane>.md)" < /dev/null > /tmp/<lane>.log 2>&1 &)
```

   Why each element: prompt file avoids inline-quoting stdin hangs (5KB
   inline prompts died at exit 144); `< /dev/null` prevents blocking on
   stdin; `setsid` survives session restarts (non-detached lanes died with
   the parent on 2026-07-05); log redirect preserves evidence and quota
   errors.
3. After 3–5s, confirm the log exists and has bytes (`wc -c`). A tiny dead
   log means the dispatch itself failed — read it before assuming the lane
   runs.
4. Cap parallelism at ~8 lanes (29-wide got OOM-killed on the 15GB box).
   Respect quota as a budget; keep an overnight reserve.
5. If the lane writes a new typed value (enum variant, schema field), the
   owner lands the type change FIRST — a lane writing data the code cannot
   parse poisons fixtures incrementally.

## Supervise

- **Completion = process gone AND deliverable exists.** Never rely on a log
  substring: lanes that read transcripts or codex logs quote `tokens used`
  and false-positive as done. Check `pgrep -f "codex exec"` plus the
  deliverable path from the prompt.
- Poll cadence: single 5–12 minute lanes get a ~270s first poll; waves get
  25–30 minutes. For long batches poll every ~10 minutes and verify
  liveness — log growth since last check AND a live process — not just
  completion.
- After dispatching, always end the turn with a scheduled wakeup. Detached
  lanes are invisible to the harness; persistent background pollers and
  sentinels get killed by the environment — the wakeup is the reliable
  path.
- For marathon runs, arm the dead-session supervisor (see
  `tools/agent-supervisor/README.md`), which revives the session inside tmux
  (interactive) or via a print-mode pulse as fallback while lanes still run.

## Harvest

1. Read the tail of the log and the deliverable.
2. Owner-verify before integrating: path-scoped diff review against the
   allowed edit paths, run the named gates/tests yourself, screen against
   the product invariants (for models work: golden inventory, layered loss,
   check rows intact). Lanes fail by optimizing the wrong objective, not by
   failing to code.
3. Commit immediately and path-scoped (`git -C <absolute repo path> add <lane paths>`)
   — uncommitted lane output in the shared checkout eventually gets wiped
   (three finished lanes lost at 2026-07-05 14:32).
4. Refill the freed lane slot in the same wake.

## Recover

Classify a lane with no completion before acting:

- **Quota text in the log** ("You've hit your usage limit"): keep the
  prompt, redispatch after reset; write the next-day plan into the dossier
  if quota is gone for hours.
- **Live process, no log growth** across two checks: hung — inspect, then
  kill; a resume once froze ~1h at a 3KB log while its edits were already
  in the tree, so diff the working tree before assuming the work is lost.
- **No process, partial log**: find the rollout under
  `~/.codex/sessions/YYYY/MM/DD/` (grep for prompt text), then
  `codex exec resume <session-id> "<narrow follow-up>"`. Never
  `resume --last` when more than one lane may have run — it races.
- **Patch-mismatch chatter in the log**: the checkout moved under the lane;
  narrow the resume prompt and require it to re-read current files.

## Modes

Regular mode only: never fast mode, never priority service tier.
Read-only mining/exploration lanes: `-c model_reasoning_effort="medium"`.
Implementation lanes: the xhigh default.
