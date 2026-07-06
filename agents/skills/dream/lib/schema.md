# Finding schema

Every scanner emits a JSON array of **findings**. One finding = one piece of
evidence that the repo's instruction surface (CLAUDE.md, skills, docs/, AGENTS.md)
is misaligned with how Anders actually wants the agent to work or what it needs
to know. Keep findings atomic — one observation each. Do not pre-aggregate; the
reducer handles frequency-weighting across sessions.

```json
{
  "finding_id": "019ed4e0-c946-7d60-934b-e0c78e0bd6f0:meta|correction|AGENTS.md|...",
  "session_id": "019ed4e0-c946-7d60-934b-e0c78e0bd6f0",
  "session_date": "2026-06-17",
  "domain": "meta | project",
  "type": "repeated_instruction | correction | frustration | rework | unanswered_question | preference",
  "evidence": "<verbatim quote from Anders, trimmed to the load-bearing sentence>",
  "agent_assumed": "<what the agent did or assumed that was wrong/suboptimal — empty if N/A>",
  "user_wanted": "<what Anders actually wanted, stated as a durable rule>",
  "doc_fixable": true,
  "target": "CLAUDE.md | AGENTS.md | docs/<file>.md | skill:<name> | unknown",
  "fix_kind": "add | rewrite | delete",
  "fingerprint": "<stable normalized finding fingerprint, added by collect>",
  "evidence_key": "<stable normalized quote key, added by collect>",
  "status": "open | proposed | applied | dismissed | deferred",
  "confidence": 0.0
}
```

## Field rules

- **domain** — the most important field. Both are first-class:
  - `meta` = *how we work*: orchestration, when to parallelize vs serialize, goal-setting, verification rigor, speed/altitude, how much to ask vs act, pushback calibration, reporting style, tool conventions. These usually target `CLAUDE.md` or `docs/`.
  - `project` = *domain specifics*: domain terms, product invariants, app architecture, tooling quirks of the repo being mined. These usually target `AGENTS.md`, a specific `skill:`, or the owning `docs/` file.
- **type**:
  - `repeated_instruction` — Anders said the same thing he's likely said before / should not have to say.
  - `correction` — "no", "don't", "actually", "that's wrong", redirecting the agent.
  - `frustration` — visible dissatisfaction with output or process.
  - `rework` — Anders took over, redid, or threw away the agent's work.
  - `unanswered_question` — the agent asked something a good doc would have pre-answered, OR fumbled for lack of a documented fact/convention.
  - `preference` — a stated like/dislike about style or approach worth encoding.
- **evidence** — verbatim. This is what makes the proposal trustworthy. Quote Anders, not the agent (except when capturing what the agent asked).
- **doc_fixable** — `false` when the friction is a model limitation, a genuinely novel one-off, or Anders changing his own mind mid-task. False findings are still logged (they're useful signal) but the reducer drops them from proposals.
- **finding_id** — deterministic id added during collect as `session_id:fingerprint`. Use this id in `proposed-changes.json` and `decisions.json`; legacy decisions may still reference `fingerprint`.
- **fingerprint** — deterministic normalized key for the atomic finding. It is stable enough for ledger updates and legacy matching, but it is not an independence count by itself.
- **evidence_key** — deterministic normalized key for Anders' quoted evidence. The reducer uses this to avoid overcounting the same utterance repeated across forked or parallel sessions.
- **status** — ledger lifecycle state. The only allowed values are `open`, `proposed`, `applied`, `dismissed`, and `deferred`.
- **confidence** — 0.0–1.0. How sure are you this is a real, generalizable misalignment vs a one-off.

## What is NOT a finding

- Normal back-and-forth, clarifying questions on genuinely ambiguous new work.
- The agent being corrected on something already documented (that's an attention failure, not a doc gap) — unless it recurs enough to suggest the doc needs to be louder/relocated.
- Anything you'd need this conversation's context to understand.
