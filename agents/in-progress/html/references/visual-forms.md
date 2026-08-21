# Visual forms

Use this as a repertoire, not a template catalog. Pick the form whose visual
grammar matches the question, combine forms when they advance one reading
order, and remove forms that merely repeat the prose.

## Editorial explanation

Build a sequence of sections with one communicative job each. A useful arc is
conclusion, comparative figure, direct annotation, nearby caveat, then the
decision or question that follows. Long pages earn their length by moving the
argument forward.

## Comparison and direction

Use side-by-side panels for before and after, alternatives, or design
directions. Keep the comparison axes identical and make the meaningful
difference visible. Small semantic blocks such as borrow/leave or
strength/liability work when the categories are genuine judgments rather than
decoration.

## Routes, relationships, and sequences

Use Mermaid when the information is naturally graph-shaped and the target
browser can load it reliably. Use hand-built HTML or inline SVG when placement,
annotation, visual weight, or editorial control matters more than automatic
layout.

For architecture and data paths, begin at the file, package, module, or system
level. Descend into methods only when method order is the question. Label nodes
with recognizable names and short ownership notes; label edges when the
transition itself carries meaning.

For time or causality, use a sequence, timeline, or scenario tree. Show the
branching conditions and outcomes, not every incidental event.

## Annotated figures

Inline SVG is useful for request paths, mechanisms, spatial relationships, and
other explanations where a custom composition communicates better than a
generic graph. Give it a stable `viewBox`, direct labels, restrained strokes,
and annotations close to the relevant marks. Prefer a legible static figure to
an interaction that reveals no additional meaning.

## Code and changes

Use syntax-highlighted code or a diff when exact text is the evidence. Preserve
enough surrounding structure to show ownership and order, highlight only the
material lines, and explain the consequence beside the excerpt. A shallow file
tree can orient the reader before a diff without exposing an entire call stack.

## Tables and inventories

Use a table for repeated fields, factual inventories, rankings, or exact
lookups. Align comparable values, keep labels concrete, and link names or
sources to their destinations. Add a chart only if a relationship becomes
materially easier to see.

## Provenance

These forms preserve useful ideas from:

- Anthropic's [HTML effectiveness gallery](https://github.com/anthropics/html-effectiveness), especially its [annotated flowchart](https://github.com/anthropics/html-effectiveness/blob/main/13-flowchart-diagram.html), [research explainer](https://github.com/anthropics/html-effectiveness/blob/main/14-research-feature-explainer.html), and [SVG illustrations](https://github.com/anthropics/html-effectiveness/blob/main/10-svg-illustrations.html).
- HumanLayer's [Show Me](https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me) skill for small technical views, shallow trees, and diff-shaped explanations.
- Matt Pocock's [Improve Codebase Architecture](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture) report patterns for mixing graph-shaped Mermaid with editorial HTML and SVG.

Their layouts are evidence and inspiration, not a single mandatory style.
