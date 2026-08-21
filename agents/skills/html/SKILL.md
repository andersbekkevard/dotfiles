---
name: html
description: Create a browser artifact from the current material and open it on Anders's Mac. Owns what to show, how to show it, and the house visual language.
disable-model-invocation: true
---

# HTML

One responsibility: turn one body of thinking into a single HTML file that
communicates it visually, and put that file open in front of Anders. Invoking
this skill means "make the clearest browser artifact you can" — Anders does not
pre-specify layout, diagram type, or interaction.

## Decide what to show

This is the load-bearing step. The page is an argument, not a transcript of the
work. Before writing any HTML:

1. Name the few claims the page exists to make. Each section carries one, and
   its heading states the claim ("Mine these. Do not merge them."), not the
   category ("Analysis").
2. For each claim, pick the form that makes its relationship visible — read
   [forms.md](references/forms.md) to choose among comparisons, flows,
   annotated figures, code views, tables, and explainers.
3. Lead with the finding. Keep each caveat beside the evidence it qualifies.
   End a decision-shaped page with the questions Anders can now answer.

Match abstraction to the question: a system route is usually file-to-file or
module-to-module; descend to methods only when call order is the question. A
page of uniform stacked cards means the content's shape hasn't been found —
return to step 2. If a figure needs a paragraph to explain its basic reading,
redraw the figure.

Wherever a URL exists — repository, document, post, ticket, finding — make the
name or claim a link, placed where the claim relies on it. In a matrix or
chart, every named entity is reachable through its label. A page whose sources
appear only in a footer has failed this rule.

## Visual language

[assets/page.css](assets/page.css) is the house language: palette, type roles,
and component grammar distilled from Anthropic's html-effectiveness gallery.
Inline the whole file into the artifact's `<style>` block and add
page-specific rules after it. [assets/skeleton.html](assets/skeleton.html)
shows every component rendered with correct markup — start from it and gut it.

Tokens are fixed; composition is free. The same stylesheet should produce a
flowchart explainer, a triage board, and a research memo that look like one
hand made them, while each page's structure comes from its subject. Consistent
care, not a consistent layout. Extend with page-specific CSS and SVG whenever
the subject demands a form the stylesheet lacks — keep the tokens while doing
so, and keep color semantic: one meaning per hue per page.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself — it owns quantitative judgment; this skill still owns
the page, delivery, and verification. When Anders should make a decision in the
browser — triage, ranking, selection, tuning — read
[interactive.md](references/interactive.md) for the decision-surface shape and
copy-back contract. Most artifacts are read, not operated.

## Build

One self-contained `.html` file, no build step, real names and data from the
actual subject. The inlined stylesheet makes CSS frameworks unnecessary.
Mermaid via CDN is acceptable when the relationship is graph-shaped, automatic
layout serves it, and the viewing context has network; hand-built SVG with
`page.css` flow classes when placement, emphasis, or annotation carry the
meaning. Everything else inlines.

Write the file outside the repository unless it is a project deliverable:
resolve `${TMPDIR:-/tmp}` and use a descriptive timestamped filename.

## Deliver

The artifact is delivered when it is open on Anders's Mac, not merely on the
machine that ran the agent. Use the installed `fleet` skill to put and open it
there. Always report the absolute path on the Mac.

Verify the rendered page before handing over: wide (~1440px) and narrow
(~390px) widths, no horizontal page overflow, no console errors, source links
resolve, every relied-on interaction works. For loading or live state, check
the route to the final state, not only the final frame.

Done when the opened artifact answers the original question visually and the
rendered checks pass.

## Open questions

- Whether the house stylesheet should grow real chart primitives or keep
  deferring all quantitative form to `tufte-viz`.
- The interactive share is estimated below 40% of uses; revisit the reference
  split if real use disagrees.
- Whether a dark variant is ever wanted; `page.css` currently commits to light.

## Provenance

- [anthropics/html-effectiveness](https://github.com/anthropics/html-effectiveness)
  (cloned at `agents/references/html-effectiveness/` in the dotfiles repo) and
  Thariq Shihipar's essay
  [The unreasonable effectiveness of HTML](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html)
  — the palette, type roles, canvas treatment, details-on-demand, and editor
  copy-back patterns in `page.css` and the references.
- Matt Pocock's Improve Codebase Architecture report format — diagram-first
  candidate cards, Mermaid/hand-built SVG mixing, "redraw the diagram" rule.
- The 2026-08-21 last30days research report Anders endorsed — take/leave
  blocks and point-of-claim source links.
- Ben Shneiderman's "overview first, zoom and filter, details on demand".
- Edward Tufte via the installed `tufte-viz` skill — the arc of conclusion,
  comparative figure, direct annotation, nearby caveat, then decision.
