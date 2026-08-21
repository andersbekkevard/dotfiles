# Provenance

`html-d` is a local synthesis, not a copy of any single upstream skill. It was
written 2026-08-21 from Anders's stated preferences and the sources below,
deliberately without reading the sibling candidates `html-b/` or `html-c/`, so
the interpretations stay independently comparable.

The candidate is registered as local in `agents/skill-sources.toml`; the source
links below retain the provenance needed for later comparison.

## Sources and what was borrowed

- [anthropics/html-effectiveness](https://github.com/anthropics/html-effectiveness)
  and the essay
  [The unreasonable effectiveness of HTML](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html)
  (Thariq Shihipar) — the visual-language target (editorial hierarchy,
  semantic color, direct annotation, details on demand) and the editor
  examples' clipboard copy-back pattern. The essay's advice to let recurring
  use shape the skill before hardening it matches this candidate's
  work-in-progress framing.
- [plannotator/effective-html](https://github.com/plannotator/effective-html)
  — narrow ownership with progressive references instead of one broad
  workflow; consistent care over a consistent look.
- [dogum/html-artifacts](https://github.com/dogum/html-artifacts) — compact
  recognition of when HTML beats Markdown, and the warning that uniform
  generic cards signal an unfound content shape.
- [nicobailon/visual-explainer](https://github.com/nicobailon/visual-explainer)
  — the browser-realistic verification pass (viewport widths, overflow,
  console errors). Its aesthetics, command surface, and runtime stack were
  intentionally left behind.
- [f-labs-io/agent-html-skills](https://github.com/f-labs-io/agent-html-skills)
  and [nexu-io/html-anything](https://github.com/nexu-io/html-anything) —
  structured export of browser state back to the agent. Their listeners,
  publishers, template catalogs, and adapters were intentionally left behind.
- Ben Shneiderman,
  [The Eyes Have It (1996)](https://doi.org/10.1109/VL.1996.545307) —
  "overview first, zoom and filter, then details-on-demand", carried here as
  conclusion-first sections with details on demand.
- Research memo and visual report produced for Anders on 2026-08-21
  (`~/.codex/visualizations/2026/08/21/01a02478-a232-7f42-89bb-3890a3f85970/`)
  — the popularity-versus-fit survey behind the source choices above, and a
  concrete exemplar (take/leave pairs, semantic olive/rust, claim-shaped
  section heads) that Anders endorsed.
