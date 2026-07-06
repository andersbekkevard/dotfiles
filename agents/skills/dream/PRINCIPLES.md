# Learning-Loop Principles

Shared contract for the two halves of the learning loop: `reflect` (hot —
written per session, from live context) and `dream` (cold — mined across
sessions, human-gated). Reflections are dream's primary input: a session with a
reflection is read through it, and transcript mining is the fallback for
unreflected sessions.

## What counts as a learning

A learning is a **recurring, doc-fixable pattern**: something that changed (or
should change) how the agent works, and that an edit to the instruction
surface — `AGENTS.md`, `CLAUDE.md`, meta-docs, a skill — would durably fix.
Not learnings: one-off mistakes, model limitations, Anders changing his mind,
implementation details of the session's product work.

## Evidence standards

- Every claimed pattern cites concrete evidence: a quote (or close paraphrase)
  plus its session date; a file path and line when the evidence is on disk.
- Recurrence is counted by **independent evidence**, not raw session count —
  two sessions echoing the same incident are one observation.
- Honest confidence: emit uncertain observations at low confidence rather than
  suppressing them; ranking is the reducer's job, not the observer's.

## Dedup keys

A pattern's identity is its **behavioral fingerprint** — the situation plus the
correction, not the wording. Same trigger, same fix → same finding, however
differently phrased. Suppressions (`suppressions.jsonl`) match on this
fingerprint; a dismissed pattern never resurfaces under a new phrasing.

## The boundary: memory / instruction surface / narrative

- **Instruction surface** (dream's only edit target): durable *how-to-work*
  rules that hold for future sessions, authored and human-approved.
- **Memory** (harness memory files): who Anders is, project state, pointers —
  facts, not process rules. A fact that expires with the project does not
  belong in `AGENTS.md`.
- **Narrative** (reflections, ledgers, proposals): the record of what happened
  and what it suggested. Never edited retroactively; never treated as policy.
  A reflection *proposes*; only the human gate *promotes* into instruction.

## Keep the surface lean

Every dream run looks for what to delete or merge, not just what to add. A
bloated instruction file aligns the agent less, not more. When a new rule
subsumes an old one, the proposal must say which lines it retires.
