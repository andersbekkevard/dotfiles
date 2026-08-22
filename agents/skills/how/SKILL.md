---
name: how
description: "Explain how a subsystem works, trace a runtime flow, or answer placement, ownership, and layering questions. Use for code walkthroughs before a change; add critique when the user asks for architectural issues or improvements. Use why for motivation."
---

# How

Explore the codebase and explain a subsystem at the level of a senior engineer
onboarding into it. Build a working mental model rather than annotated source.

Two modes:

1. **Explain** is the default.
2. **Critique** explains first, then runs independent architectural critics.

## Explain

### Scope

Interpret the question and state a best-guess scope when it is ambiguous. Let
the user redirect rather than interviewing them.

For a narrow function, utility, or single module, use one fresh read-only
explainer that explores and writes the answer. For a subsystem spanning several
modules or services, divide the question into two to four distinct exploration
angles and investigate them concurrently. Lean toward the simpler path.

### Explore complex systems

Give each fresh explorer the same base instructions from
[explorer-prompt.md](references/explorer-prompt.md) plus one named angle. Each
explorer traces actual code from an entry point through the call chain, data
flow, types, and boundaries. It returns components, the traced flow, every file
read, non-obvious behavior, and open gaps.

Once all slices return, give their findings to one fresh explainer using
[explainer-prompt.md](references/explainer-prompt.md). The explainer reconciles
overlap and contradictions, checks source where needed, and writes one coherent
mental model.

For a simple question, the explainer performs the exploration itself with the
same output contract.

### Present

Present the explanation, lightly edited for the conversation. Adapt this shape
to the question:

- **Overview:** what it is, what it does, and why it exists.
- **Key concepts:** only the types and abstractions needed to follow the flow.
- **How it works:** trigger, sequence, data movement, and decision points, with
  specific source references.
- **Where things live:** the small file map needed to start working.
- **Gotchas:** non-obvious behavior, sharp edges, and relevant historical
  constraints.

## Critique

Use critique mode when the user asks for architectural problems or
improvements. Complete the explanation first; understanding precedes judgment.

### Run three independent critics

Create one immutable critic packet containing:

1. The completed explanation.
2. The relevant source files or exact source excerpts, labelled with paths and
   line ranges.
3. [The architectural rubric](references/critique-rubric.md).
4. [The critic prompt](references/critic-prompt.md).

Launch all three critics through one closed
[model wave](../model-wave/SKILL.md) with the same packet and no tools or
repository access:

| Harness | Model | Effort |
|---|---|---|
| Claude Code | Fable 5 | high |
| Codex | GPT-5.6 Sol | high |
| Grok Build | Grok 4.6 | high |

These are minimum reasoning levels. Increase effort when the architecture
warrants it. Do not substitute another model silently when a runner fails.

Model wave delegates each lane to its provider dispatcher. Keep the runs
prompt-only and independent; a dropout remains visible.

### Judge

Read every critique and check its evidence against the source packet. Act as a
pragmatic lead rather than an aggregator. Classify each finding:

- **Act on:** worth fixing now.
- **Consider:** real, but cost or priority remains uncertain.
- **Noted:** valid and low priority.
- **Dismissed:** incorrect, context-free, or merely stylistic.

Present the standalone explanation first, followed by the lead's critique
verdict. Keep model claims, source evidence, and accepted judgment distinct.
