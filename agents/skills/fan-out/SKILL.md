---
name: fan-out
description: "Orchestrate parallel subagent work with the standard worker contract: disjoint scopes, parallel-safety block, verifiers, numbered-findings consolidation. Use for 'kick off one agent per X', 'spawn subagents', MECE audits, parallel implementation, or any multi-worker fan-out."
---

# Fan-out

The standard orchestration harness for in-harness subagent waves — it replaces
the hand-typed boilerplate, not your judgement. You are the orchestrator: you
decompose, spawn, consolidate, and report. Workers do the work. (Detached
background codex work is a different mechanism: the `codex-lane` skill owns
that lifecycle; worker-model choice follows the global model-economics rules.)

## Ground rules (all variants)

- **≤6 workers in parallel** (hard cap for in-harness subagents; batch if more
  units — separate from the ~8 detached codex-lane budget, which is a
  different pool).
- **Thread/agent naming: `{entity}_{task}`** (e.g. `parser_ingestion`,
  `compute_audit`).
- **Worker prompts are self-contained.** A worker has zero conversation
  context: include the repo path, the mandatory reads (nearest `AGENTS.md` +
  task-relevant docs), the task, the scope, and the report format. No "as
  discussed above".
- **Every worker prompt includes the parallel-safety block:**

  > You are not alone in the codebase. Other agents edit unrelated areas
  > concurrently in this same checkout (not a worktree). Never revert,
  > reformat, or overwrite changes outside your scope; if a central file
  > changed under you, re-read it and patch around it. Do not commit. Do not
  > start, stop, or restart shared dev servers (see the owning app's
  > `AGENTS.md`).

- **Pin the acceptance gate before spawning.** Write the desired end state and
  a short acceptance checklist (3-5 verifiable points) *first*, and put it in
  every worker prompt. Large fan-outs drift when the end state lives only in
  the orchestrator's head.
- **Decisions don't evaporate.** Any decision made mid-fan-out gets captured
  in the closeout per the repo's decision-record conventions (ADR, Note, or
  equivalent), or it didn't happen.

## Variant A — implementation fan-out

- Declare **disjoint write scopes** per worker, explicitly listing owned files/
  directories. "Do NOT edit outside your scope" in every prompt.
- The orchestrator does not touch code; only workers do.
- Each worker verifies its own lane before reporting — the repo's
  task-appropriate gate (`check`/`test`/`build` command) — and reports
  PASS/FAIL, changed files, commands run, blockers.
- After all workers return, run an independent verification pass (Variant C)
  on the integrated result before reporting to Anders.

## Variant B — MECE read-only audit

- Partition the surface into a MECE set (≤6 partitions); one worker each.
- Worker contract: *"Read-only — do not edit. Own ONLY your partition. Return
  severity-ranked, **numbered** findings with exact `file:line` references.
  Separate intentional choices from genuine gaps."*
- Audit the **live tree**, not a prior report; never trust an earlier
  critique's claims without re-verifying.
- Score lanes only when asked; the default deliverable is findings, not grades.

## Variant C — independent verifier loop

- After implementation, spawn a **read-only verifier** that did not write the
  code: it checks the result against the acceptance gate (and reference
  screenshots for visual work), returning either `ACCEPTED` or severity-ranked
  numbered issues.
- Loop implement → verify until ACCEPTED or a blocker needs Anders.

## Consolidation & report

- Merge worker output yourself; resolve overlaps and contradictions before
  Anders sees them.
- **All findings numbered and independently actionable** — Anders triages by
  number ("fix 2, 5, 8"). Prose findings that can't be selected are a defect.
- End with: ranked actionables, decisions needing Anders (numbered), and the
  acceptance-gate verdict.
- Big audits may additionally render to a single self-contained HTML under the
  repo's analysis-output location when Anders asks for something browsable.
