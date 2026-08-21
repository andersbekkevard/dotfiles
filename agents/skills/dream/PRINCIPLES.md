# Dream audit principles

## What counts as a learning

A learning is a recurring, doc-fixable pattern that changed, or should change,
how the agent works. A one-off mistake, model limitation, implementation detail,
or Anders changing his mind is evidence about the session, not a durable rule.

## Evidence

Treat the original dialogue as primary. Every pattern needs an exact quote or
close paraphrase with a session date and enough context to relocate it. Count
recurrence by independent evidence. Forks or summaries repeating the same
moment count once.

Emit uncertain observations at low confidence. The reducer ranks them.
Historical reflections may point to evidence but cannot establish a finding
without the transcript.

## Identity

Identify a pattern by its situation and correction, not its wording. The same
trigger and fix share one behavioral fingerprint even when phrased differently.

## Authority

Instruction files contain reviewed rules for future work. Memory contains facts
and project context. Audit findings, ledgers, and proposals record what happened
and what it may suggest. They are not policy until Anders reviews and promotes
them.

## Keep instructions lean

Look for stale, duplicated, or contradictory guidance as actively as missing
guidance. Prefer rewriting, consolidating, or deleting an existing rule over
stacking another rule beside it.
