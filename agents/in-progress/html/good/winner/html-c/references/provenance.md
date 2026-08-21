# Provenance and confidence

This candidate was created without reading or comparing the existing HTML
skills under `agents/in-progress/`. It combines Anders's instructions in the
August 2026 design conversation with the sources below.

## Primary sources

- [Thariq Shihipar's article](https://claude.com/blog/using-claude-code-the-unreasonable-effectiveness-of-html)
  supplied the core idea: use HTML when spatial structure, interaction, or
  throwaway tooling communicates better than Markdown.
- [Anthropic's HTML effectiveness gallery](https://github.com/anthropics/html-effectiveness)
  supplied the strongest visual evidence. The most relevant examples are visual
  directions, code review, code understanding, SVG illustration, annotated
  flowchart, research explainer, triage board, feature flags, and prompt tuner.
- [Effective HTML](https://github.com/plannotator/effective-html) contributed
  content-shaped design, narrow ownership, and consistent care without a fixed
  look.
- [HTML Artifacts](https://github.com/dogum/html-artifacts) contributed the
  recognition that HTML should reveal the content's shape rather than restyle a
  Markdown outline.
- [Visual Explainer](https://github.com/nicobailon/visual-explainer) contributed
  code and diff mechanics, responsive checks, accessibility, overflow control,
  and browser verification.
- [Agent HTML Skills](https://github.com/f-labs-io/agent-html-skills) contributed
  the browser-to-agent feedback question. Anders currently prefers clipboard
  export over its coupled listener approach.

The local research memo is
`/Users/andersbekkevard/.codex/visualizations/2026/08/21/01a02478-a232-7f42-89bb-3890a3f85970/html-is-the-new-markdown-research.md`.
Its popularity evidence was useful, but later choices from Anders supersede its
recommendations where they differ from this skill.

## Anders decisions encoded now

- Aim for the visual clarity and communication quality of Anthropic's examples.
- Prefer abstract file, module, or actor paths to full call stacks unless the
  task is debugging the stack itself.
- Keep Show Me and TufteVis standalone. Borrow focused ideas without modifying
  or absorbing either skill.
- Tailwind and Mermaid through CDNs are acceptable for local artifacts.
- Source links belong throughout the report.
- Open the artifact on Anders's Mac and report its absolute Mac path.
- Use details-on-demand when it protects the overview.
- For interactive decisions, start with copy-as-Markdown rather than an
  automatic round trip.
- Keep design-specific slider and card-variant tooling out of the ordinary path.

## Open hypotheses

- Whether a shared stylesheet or growing component library should provide a
  recognizable Anders visual style.
- Which parts of Show Me's successful technical presentation belong in a future
  code-and-diff reference.
- Whether repeated use justifies a local listener or another automatic return
  channel.
- How much of the Anthropic editorial palette should become a default instead
  of an example.

Treat these as questions to test through use. Do not turn them into stricter
requirements until Anders decides or repeated evidence supports the change.
