# Visual communication

Read this reference when the artifact's main job is explanation, comparison,
review, or orientation.

## Start with the point

Decide what the reader should see that prose hides. Give each section one
communicative job. A strong section usually has a claim, a figure or structured
comparison, and a short annotation or caption. Let the figure carry the weight.
If it needs a paragraph to explain what the reader should notice, redraw it or
change the form.

Use the subject's own nouns and real values. Label important relationships
inside the figure. Annotate exceptional edges, thresholds, risks, and changes
where they appear. Use legends only for repeated visual grammar.

Start with an overview. Offer zoom, filtering, or details-on-demand when deeper
material would otherwise bury the main point. Details should preserve context,
not open an unrelated miniature page.

## Match the form to the material

- For a request path or responsibility path, show the smallest useful chain of
  files, modules, systems, or actors. Prefer semantic steps over an exhaustive
  call stack. Put the implementation location beneath the semantic label.
- Use Mermaid for dependencies, sequences, and flows when automatic graph
  layout communicates the relationship cleanly.
- Use inline SVG for deliberate geometry, direct annotation, cross-sections,
  mass diagrams, or a flow whose emphasis depends on exact placement.
- Use a shallow monospace tree for file ownership or broad refactor shape.
- Use side-by-side composition for alternatives, before and after states,
  visual directions, and diffs. Keep the compared dimensions aligned.
- For code review, lead with what changed and the risk map. Show focused diff
  hunks with line-level annotations. Collapse safe or secondary files behind
  details-on-demand.
- For a mixed report, vary the visual form by claim. A matrix, annotated figure,
  ruled comparison, and short table can coexist when each earns its place.

Cards are appropriate for independently comparable units. For a continuous
argument, use sections, whitespace, rules, and figures so the page reads as one
piece instead of a dashboard of unrelated boxes.

## Current visual direction

Follow an existing project's visual language when it is part of the subject.
Otherwise, the current fallback is an editorial paper treatment inspired by
Anthropic's HTML examples:

- ivory or warm paper background;
- near-black ink and quiet oat or gray rules;
- clay for focus, warning, or the active thesis;
- olive for retained, approved, successful, or completed states;
- serif display type, readable system sans prose, and mono metadata labels;
- generous whitespace, thin rules, restrained borders, and little decorative
  depth.

This is a starting direction, not a mandatory house style. Preserve its
principles when changing its appearance: clear hierarchy, semantic color,
strong comparison, direct annotation, and enough quiet space for the figure to
read.

Use soft semantic fills for paired judgments such as borrow and leave, retain
and reject, or current and proposed. Color should still work with labels and
shape when viewed without color.

## Figures and sources

Give figures useful titles and accessible text. Keep labels legible at the
actual viewport, not only at full SVG size. Use consistent strokes and box
geometry within one figure. Make the focal node visibly different and explain
what the difference means.

Link source-backed findings where the reader encounters them. A project name,
claim, number, or quoted phrase should usually be the link. Keep a compact
source footer for the full evidence set, but do not make the footer the only way
to audit the report.
