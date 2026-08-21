---
name: reconstruct-sessions
description: Reconstruct what happened across a scoped set of past sessions.
disable-model-invocation: true
---

# Reconstruct sessions

Read and follow [`mine-sessions`](../mine-sessions/SKILL.md) for session
discovery, extraction, sharding, fan-out, and reduction.

Ask the session corpus:

> Reconstruct the flow of work: what Anders intended, what was investigated or
> built, which decisions were made, what evidence supports completion, what
> remains unresolved, and what other work may be affected.

Preserve Anders' messages verbatim where they carry intent or decisions.
Distinguish what workers claimed, what evidence verifies, what Anders accepted,
and what remains unsettled. Keep enough identifiers and source session IDs to
recover detail later. Compress implementation detail unless it changed a
decision, explains an important outcome, or is needed to recover the detail.

Return one compact reconstruction to the requesting conversation. Do not
rewrite planning or documentation unless Anders separately asks.

Done when every scoped session is accounted for and the reader can resume the
work without reading the original sessions.
