---
name: dream-next
description: Audit past sessions for recurring failures in skills, instructions, delegation, verification, and workflow, then propose narrow reviewed changes.
disable-model-invocation: true
---

# Dream next

Audit how the agent system has been working. Read and follow
[`mine-sessions`](../mine-sessions/SKILL.md) for all session discovery,
extraction, sharding, fan-out, and reduction mechanics.

Ask the session corpus:

> Where did skills, instructions, delegation, verification, or workflow cause
> agents to diverge from Anders' intent? Find repeated corrections, frustration,
> rework, missing guidance, stale guidance, and changes in Anders' preferences.

Compare the evidence with the current skills and instruction files. Treat
Anders' words in the original transcript as primary. A reflection may point to
useful evidence but cannot establish a pattern by itself.

For each supported pattern, explain the observed behavior, the correction
Anders wanted, independent recurrence, likely owner, and the narrowest useful
addition, rewrite, consolidation, or deletion. Distinguish what a worker
claimed, what the evidence supports, what Anders accepted, and what remains a
hypothesis. Recent explicit preferences can supersede older ones even when the
older wording appears more often.

Produce a compact audit report for Anders. Propose changes without editing
skills, `AGENTS.md`, `CLAUDE.md`, prompts, or workflow. Promotion happens only
after review.

Done when the report accounts for the scoped sessions, links each proposed
change to exact evidence, and leaves one-off or unsettled observations clearly
unpromoted.
