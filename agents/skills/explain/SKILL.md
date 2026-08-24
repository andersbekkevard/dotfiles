---
name: explain
description: Explain complex material as an HTML artifact with a clear argument, visual journey, evidence, and caveats.
disable-model-invocation: true
---

# Explain
Answer a question from anders visually as opposed to a block of text.
The goal is to reduce the friction of communication, and make it easier and lower friction
for Anders to understand what you are trying to communicate.

# Explanatory forms

Choose forms by the relationship the reader needs to see.
| Subject shape | Useful form |
|---|---|
| Alternatives, change, recommendation | Side-by-side comparison, before/after on identical axes, take/leave pair |
| Dependency, flow, sequence | Flow or sequence diagram |
| Mechanism, placement, spatial relationship | Directly annotated figure |
| Dense inventory, ranking, lookup | Linked table with direct labels |
| A decision made in the browser | Read [interactive.md](interactive.md) |

However, just splitting up a block of text into side by side blocks of text is not useful.
Empathize with Anders' brain. What visual would most easily communicate the idea?
- Figure?
- Diagram?
- Highlight sections?

Badly written text is also high on mental load for Anders. 
Use `unslop` to communicate clearly.

Use small multiples when the reader must compare periods or measures.
Match abstraction to the question. A system route is usually module-to-module;
descend to methods only when call order is the question.

For a concrete code shape, file tree, call path, or diff, use `show-me` to
select the smallest useful visual and include that result in the page
specification.

When the page exists for Anders to make a decision, read
[references/interactive.md](references/interactive.md). When the material is
primarily quantitative, use `tufte-viz` for the analytical and graphical
judgment.

Exact text and numbers are evidence. Preserve the relevant source material and
put each source link beside the claim it supports. A footer may summarize
coverage but cannot be the only place sources appear.

Invoke the `html` skill for making the actual artifact

Done when the opened artifact gives the reader a coherent path through the
material and makes the intended concept or decision clear.
