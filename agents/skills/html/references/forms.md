# Visual forms

A repertoire, not a template catalog. Pick the form whose grammar matches the
subject's structure; combine forms when they advance one reading order. Local
exemplars live in the dotfiles repo at `agents/references/html-effectiveness/`
— read the named file when a form is close to your subject; each is a complete
page in the house visual language.

| Subject shape | Form | Exemplar |
|---|---|---|
| Alternatives, a change, a recommendation | Side-by-side `.cols`, before/after on identical axes, take/leave pairs | `01-exploration-code-approaches.html`, `02-exploration-visual-designs.html` |
| Dependency, flow, sequence | Mermaid graph, or hand-built `svg.flow` with the page.css node/edge classes | `13-flowchart-diagram.html` |
| Mechanism, placement, spatial relationship | Hand-built annotated SVG; labels sit on the marks | `10-svg-illustrations.html` |
| Research or concept explanation | Mental model first, then route, evidence, consequence; details on demand | `14-research-feature-explainer.html`, `15-research-concept-explainer.html` |
| Status, incident, plan, PR | Sections shaped around the reader's decisions; answer first | `11-status-report.html`, `12-incident-report.html`, `16-implementation-plan.html` |
| File or code responsibility | Shallow `.tree` with per-branch notes, focused `.diff` hunks | `04-code-understanding.html`, `03-code-review-pr.html` |
| Dense inventory, ranking, lookup | Linked table with `tabular-nums`; every named row clickable | — |
| A decision Anders makes in the browser | See [interactive.md](interactive.md) | `18`, `19`, `20` |

## Choosing between Mermaid and hand-built SVG

Mermaid when the relationship is naturally graph-shaped and automatic layout
serves the story — dependencies, call flows, sequences. Initialize
`mermaid@11` ESM from the CDN with `theme: "neutral"` and wrap the diagram in
a `.canvas` so it doesn't feel parachuted in.

Hand-built SVG when exact placement, visual weight, or on-figure annotation
carries the meaning — Mermaid's layout goes generic there. Stable `viewBox`,
direct labels, restrained strokes, arrow markers defined in the SVG
(skeleton.html shows the pattern).

Editorial figures worth knowing from the Improve Codebase Architecture format:

- **Cross-section** — stacked horizontal bands for layers a call passes
  through; before: six thin do-nothing layers, after: one thick labeled band.
- **Mass diagram** — interface rectangle vs implementation rectangle per
  module; shallow modules have near-equal heights, deep ones a short interface
  over a tall implementation.
- **Call-graph collapse** — a tree of nested boxes before; the same tree
  collapsed into one box after, now-internal calls faded inside it.

## The section arc

The transferable Tufte arc, which applies beyond quantitative work:

> conclusion → comparative figure → direct annotation → nearby caveat →
> decision or question

Titles state conclusions ("gains concentrated, then Q2 gave back 12.5%"), not
chart types. Direct labels replace legend hunting; a legend earns its place
only for repeated grammar. Small multiples make periods and measures
comparable. High density without becoming a dashboard of cards.

## Code and changes

Exact text is evidence: render the actual changed lines with context, attach
findings to the relevant line or hunk, and put the consequence beside the
excerpt. A shallow tree orients before a diff. Show the meaningful files and
modules; the parts of a call stack that don't bear on a claim stay off the
page.
