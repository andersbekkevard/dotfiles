---
name: reflect
description: Reflect on friction, wasted effort, and possible improvements in the current session.
disable-model-invocation: true
---

# Reflect

Review the current conversation and tool trace. Identify where the process cost
more time, attention, or tokens than the outcome warranted.

Look especially for repeated tool calls, avoidable context loading, retries,
misunderstood tool behavior, weak prompts, poor context selection, unnecessary
implementation detail, and delegation or verification that made the chief of
staff a bottleneck. Also capture methods that clearly avoided those costs.

Explain the friction, its cause, and the smallest plausible improvement to a
skill, prompt, tool, or working convention. Distinguish a one-off problem from a
pattern worth testing again. Preserve Anders' corrections and preferences when
they bear on the conclusion.

Return the reflection in the current conversation. Keep it proportional to the
signal. Do not write a reflection file or change instructions unless Anders
separately asks.

Done when the useful friction and improvement candidates are visible without
recounting the session or inflating a small issue into a rule.
