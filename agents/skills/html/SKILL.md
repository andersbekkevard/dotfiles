---
name: html
description: "Deliver HTML to Anders. Use whenever any skill or request produces an HTML page: one self-contained file, open in his Mac browser."
---

# HTML

The caller owns what the page says and shows. This skill owns the medium.

If the caller has already rendered the HTML, preserve its visual design and
skip the rules below. Only deliver and open the finished file.

## Rendering

One file, no build step. Tailwind and Mermaid via CDN. Tailwind classes on everything you write; a style block only for what a class cannot reach: elements Mermaid or a highlighter generates, @keyframes, and one variable per hue when a color carries one meaning across the page. Mermaid for most diagrams; hand-built SVG for layouts mermaid does't support. Never use emojis; make your own illustrations and diagrams.
Write to `${TMPDIR:-/tmp}/<name>-<timestamp>.html` unless the
page is a project deliverable.

Anything the page names that has a URL or a path is a link: repos, files,
tickets, sources.

Warm off-white ground, near-black ink. A serif for titles at document scale,
a plain sans for reading, never use monospace.
Hierarchy comes from size, weight, and whitespace,
with thin rules where a break is needed. Figures sit on a raised white surface
with a soft border and carry their labels directly; a legend appears only when
a grammar repeats. Color is scarce and semantic: one or two hues, each meaning
one thing for the whole page, everything else in ink and gray. No gradients,
shadows, or decoration. The subject decides the form.

## Delivery

Delivered means open in Anders's Mac browser. For a finished file, use `fleet
mac put --open` with a fresh temporary destination directory. For a live
service, use `fleet mac forward --open`. Report the Mac URL or path.
