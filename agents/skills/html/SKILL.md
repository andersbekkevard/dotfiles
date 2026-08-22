---
name: html
description: Deliver HTML to Anders. Use whenever any skill or request produces an HTML page: one self-contained file, open in his Mac browser.
---

# HTML

The caller owns what the page says and shows. This skill owns the medium.

One file, no build step. Tailwind and Mermaid via CDN. Tailwind classes on everything you write; a style block only for what a class cannot reach: elements Mermaid or a highlighter generates, @keyframes, and one variable per hue when a color carries one meaning across the page. Mermaid for most diagrams; hand-built SVG for layouts mermaid does't support
Write to `${TMPDIR:-/tmp}/<name>-<timestamp>.html` unless the
page is a project deliverable.

Anything the page names that has a URL or a path is a link: repos, files,
tickets, sources.

The page reads like a quietly typeset document on warm paper: near-black ink,
a serif for titles at document scale, a plain sans for reading, monospace only
for labels and metadata. Hierarchy comes from size, weight, and whitespace,
with thin rules where a break is needed. Figures sit on a raised white surface
with a soft border and carry their labels directly; a legend appears only when
a grammar repeats. Color is scarce and semantic: one or two hues, each meaning
one thing for the whole page, everything else in ink and gray. No gradients,
shadows, or decoration. The subject decides the form.

Delivered means open in Anders's Mac browser. Use `fleet` to get it there and
open it; prefer forwarding over copying. Report the Mac URL or path.
