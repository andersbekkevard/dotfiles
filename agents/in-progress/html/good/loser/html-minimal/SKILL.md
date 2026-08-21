---
name: html-minimal
description: Create one clear HTML artifact, deciding what to show and how to show it.
disable-model-invocation: true
---

# HTML minimal

Determine what to show and how to show it. Different things demand different
approaches. Think and communicate in a visual way: structure the page into
meaningful sections, annotate figures directly, and choose forms that fit the
subject instead of applying one fixed layout.

For broad request paths, show the file-to-file or module-to-module
route rather than the entire call stack. Make URL references clickable wherever
possible.

Write one self-contained HTML file under `${TMPDIR:-/tmp}`, using a fresh
descriptive timestamped name. Tailwind and Mermaid via CDN are good patterns
when they fit the material. If Anders should click, select, or give structured
feedback, read [interactive.md](references/interactive.md).

Use the warm paper surface, near-black text, serif display headings, sans-serif
body, monospaced labels, rust accent, and olive/clay judgment colors from the
stylesheet. Let scale, whitespace, rules, and alignment carry hierarchy. Use
boxed regions when they represent a real group, comparison, or decision.

Keep titles concrete. Label figures directly. Give each section one
communicative job. Make useful URLs clickable wherever a source, named item, or
supporting claim has a destination.


Open the result on Anders's machine with `open -a "Comet" <path-or-url>`. If
the work runs elsewhere, find a route that puts and opens it on his Mac. Tell
Anders the absolute Mac path or usable URL.
