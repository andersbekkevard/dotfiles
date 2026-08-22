---
name: arena
description: Compare several independent attempts at the same task, choose a base, graft the strongest ideas into it, and verify the result. Use when Anders says arena or when choosing the shape is the hard part.
disable-model-invocation: true
---

# Arena

Produce several independent attempts at the same task. Judge them blind, read
every candidate, choose the strongest base, graft in the best ideas from the
others, and verify the synthesized result.

## Frame

The candidates receive the same task and selected context, so that brief is the
contract. State the artifact they should produce and derive a short rubric of
concrete criteria for this task. Candidates see the task, not the rubric.

Choose enough candidates to expose genuinely different approaches. Give each a
fresh context containing only the shared brief and necessary source material.
Keep candidate work independent: return artifacts or use distinct temporary
paths; the synthesis is the sole writer to the final target.

Unless Anders chooses another shape, run one Codex, one Claude, and one Grok
candidate through a closed [model wave](../model-wave/SKILL.md). Select models
and effort for the task rather than fixing them in this skill. Give all three
the exact same brief. Model wave owns concurrent execution, provider access
boundaries, result capture, and visible dropouts; Arena owns the comparison.

## Fan out

Launch the candidates independently. Each returns its artifact and a short
rationale naming important choices, alternatives considered, and rejected
directions. If a candidate fails, continue with the remaining candidates and
account for the dropout.

## Judge

After every candidate has finished, give an independent judge the rubric and
neutrally labelled candidates. The judge scores each criterion and recommends
a base with reasons. Do not identify candidate authors or runtimes to the
judge.

In parallel, read every candidate end to end and score it against the same
rubric. Use the judge as evidence, not authority. Resolve disagreement by
examining the candidates and their rationales rather than averaging scores.

Choose the base that best satisfies the task and can absorb improvements
without losing a coherent mental model. When candidates are otherwise tied,
prefer the clearer boundary and smaller surface.

## Graft

Inspect each losing candidate for ideas worth carrying into the base. Port
those ideas deliberately; do not paste incompatible pieces together. Keep the
result internally coherent.

If the candidates converge, use the consensus shape without inventing grafts.
If they diverge because the task was underspecified, improve the brief and run
the arena again rather than blending incompatible answers.

## Verify

Verify the synthesized artifact through the real acceptance path for the task.
The arena improves exploration; it does not replace proof.

Return one synthesized artifact and a concise account of the chosen base,
grafts, material rejections, dropouts, and verification. Write that account
durably only when the task itself calls for a durable decision record.
