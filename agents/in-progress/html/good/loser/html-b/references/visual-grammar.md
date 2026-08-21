# Visual grammar

Use this reference to decide what the artifact should look like. It records a
working visual model, not a fixed template.

## Make the subject visible

Start from the relationship the user needs to see. Pick the smallest visual
form that carries it.

| Subject shape | Useful form |
|---|---|
| Alternatives or a change | Side-by-side comparison, before and after, or borrow and leave |
| Responsibility or ownership | Columns, hierarchy, or an ownership map with the allowed dependency shown once |
| Sequence or state change | Timeline, staged flow, or sequence diagram |
| Causality or dependency | Mermaid flowchart, dependency graph, or hand-built boxes and arrows |
| Two competing dimensions | Matrix with named axes; use size only for a real third variable |
| Dense evidence | Linked table, ranked list, taxonomy, or small multiples |
| File or code responsibility | Shallow file tree, annotated diff, or call-flow sketch |
| Values that are hard to describe | A small editor with immediate preview and an explicit export |

Code-shaped visuals belong to code-shaped material. Plans, arguments, and
decisions should use their own semantic structure rather than a file tree or
architecture metaphor.

The diagram carries the explanation. If it needs a paragraph to explain its
basic reading, redraw it. Use prose for evidence, caveats, and judgment that the
visual cannot encode honestly.

## Compose the page

Use strong hierarchy and generous space. Give each section a visual job instead
of wrapping every heading in the same card.

- Let one thesis dominate the first screen.
- Use continuous editorial sections and thin rules. Use a card when the item is
  genuinely separate or interactive.
- Keep labels compact. Serif headings, sans-serif prose, and monospaced labels
  create useful contrast when the subject has no stronger visual system.
- Use color to encode a small number of meanings. Keep ordinary structure in
  neutral tones.
- Integrate words, numbers, diagrams, and source links. Do not exile evidence to
  a footer.
- Preserve exact values beside interpretive graphics. Label editorial axes as
  judgment rather than measurement.
- Design the narrow layout deliberately. Reflow relationships instead of merely
  shrinking the desktop composition.

## Proven patterns

### Borrow and leave

For adaptation decisions, pair two equal blocks:

- Pale olive means retain, borrow, or adapt useful intellectual work.
- Pale rust means leave behind the coupling or assumption that does not fit.
- A short uppercase label names the operation. The body states the concrete
  choice.

This pattern translates Anders's "LoRA instead of retraining" preference into a
repeated visual decision. It is useful when each source has both value and
liability. It is not a generic positive-versus-negative decoration.

### Ownership and direction

Use equal columns for independently owned responsibilities. Put the single
allowed dependency in a strip or arrow spanning the columns. This makes the
relationship visible without turning the whole explanation into a flowchart.

### Popularity and fit

Use a two-axis matrix when the report must keep an objective ranking separate
from an editorial judgment. Name both axes. State which axis is interpretive.
Use logarithmic placement or size for highly skewed counts, and provide the
exact values in a linked list or detail panel.

### Before and after

Use the same scale, vocabulary, and visual encoding on both sides. Change only
what the proposal changes. This works for architecture, workflows, ownership,
and interface decisions, not only code.

### File trees and diffs

Use a shallow tree to show file responsibility. Show only the branches needed
for the point and annotate each branch with its responsibility. For a diff,
render the actual changed lines, keep context visible, and attach findings to
the relevant line or hunk. These are technical patterns inside a general HTML
skill, not the default model for every subject.

## Editorial fallback

When the project has no visual system and the subject supplies no stronger
direction, begin with this research-broadsheet treatment. Vary it when the
content calls for something else.

```css
:root {
  --ivory: #faf9f5;
  --paper: #ffffff;
  --ink: #141413;
  --clay: #d97757;
  --oat: #e3dacc;
  --olive: #788c5d;
  --muted: #666a60;
  --serif: ui-serif, Georgia, "Times New Roman", serif;
  --sans: system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}
```

Use warm paper, near-black ink, one clay or rust accent, an olive secondary,
large serif headings, plain sans-serif prose, small monospaced labels, broad
whitespace, and thin dividers. Darken colors when contrast requires it. Derive
soft semantic fills from the base colors.

Treat this as a quality floor, not a signature. The stronger principle is
consistent care, not a consistent look.

## Rendering choices

Plain HTML and CSS give the most direct control. Tailwind through its CDN is a
good accelerator for layout and typography when it does not determine the
composition. Mermaid through its CDN is reliable for call graphs,
dependencies, flows, and sequences. Wrap it in the report's visual language.

Use hand-built HTML and inline SVG for editorial diagrams such as mass,
cross-section, ownership, collapse, and comparison views. Mix techniques in one
report when the subject changes shape. Keep the page static unless interaction
helps the user decide or export something.

## Source discipline

Make named findings clickable. Prefer a direct primary source or repository.
Link the words carrying the claim instead of adding a bare URL. For a chart or
matrix, make each entity reachable through its label, detail panel, or legend.
Keep a compact source summary at the end for coverage and limitations.

Separate observation from judgment:

- Observation: exact stars, dates, quoted wording, measured values.
- Judgment: fit, recommendation strength, what to borrow, what to leave.

Show both, and label the judgment.

## Evidence and provenance

This candidate draws on:

- [Anthropic's article](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html), especially information density, visual clarity, responsive reading, two-way interaction, source ingestion, and starting from the intended use before freezing a skill.
- [Anthropic's example gallery](https://github.com/anthropics/html-effectiveness) and its [gallery source](https://github.com/anthropics/html-effectiveness/blob/main/index.html), which supplied the editorial palette, type roles, spacing, thin rules, and source-shaped examples.
- The 2026-08-21 research agent's successful HTML report. Its original syntheses were the popularity-versus-fit matrix, borrow/leave blocks, and one-way ownership composition. The report adapted the gallery's visual vocabulary and passed wide, narrow, interaction, overflow, and secret checks.
- [Effective HTML](https://github.com/plannotator/effective-html), for a short general entrypoint, focused references, subject-shaped direction, and replaceable responsibilities.
- [HTML Artifacts](https://github.com/dogum/html-artifacts), for content-shaped layout, calm typography, and resistance to the generic generated-dashboard look.
- [Visual Explainer](https://github.com/nicobailon/visual-explainer), for code and diff presentation, responsive verification, accessibility, and overflow checks.
- [Agent HTML Skills](https://github.com/f-labs-io/agent-html-skills), for semantic HTML, CSS variables, and export-back interaction.

These are sources of tested ideas, not bundled dependencies. Preserve their
provenance while keeping `html-b` replaceable.
