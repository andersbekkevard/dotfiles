---
name: reflect-next
description: Reflect on how the current session was conducted and preserve useful process evidence for later review.
disable-model-invocation: true
---

# Reflect next

Review the current conversation and tool trace. Focus on how the work was done,
not on restating the implementation.

Capture only the moments that changed the process: an approach that worked, a
failure or delay, a correction from Anders, a pivot, a verification gap, or a
possible reusable lesson. Preserve exact excerpts or enough concrete detail to
relocate each moment. Distinguish observation, proposed lesson, and anything
Anders explicitly accepted.

Write a short Markdown note under `.agents/reflections/` named
`<YYYY-MM-DD>-<short-slug>.md`. Use the sections the evidence needs rather than
a fixed template. If the session contains no useful process evidence, say so
and do not manufacture a reflection.

The note is narrative evidence. It does not change instructions and has no
special authority over the original transcript.

Done when the note preserves the useful process signal without turning
implementation detail or speculation into a durable rule.
