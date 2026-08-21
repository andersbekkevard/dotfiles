---
name: html-minimal
description: Create one clear HTML artifact, deciding what to show and how to show it.
disable-model-invocation: true
---

# HTML minimal

Status: tournament candidate.

Act as the cohesive router for HTML artifacts. When Anders calls `/html`,
determine what to show and how to show it. Different things demand different
approaches. Think and communicate in a visual way: structure the page into
meaningful sections, annotate figures directly, and choose forms that fit the
subject instead of applying one fixed layout.

Aim for a clean visual overview and the visual clarity of Anthropic's
[`html-effectiveness`](https://github.com/anthropics/html-effectiveness)
examples. For broad request paths, show the file-to-file or module-to-module
route rather than the entire call stack. Make URL references clickable wherever
possible.

If the work is definitely quantitative, read and apply
[`tufte-viz`](../../../skills/tufte-viz/SKILL.md) itself. Keep it standalone;
do not reproduce its quantitative guidance here.

Write one self-contained HTML file under `${TMPDIR:-/tmp}`, using a fresh
descriptive timestamped name. Tailwind and Mermaid via CDN are good patterns
when they fit the material. If Anders should click, select, or give structured
feedback, read [interactive.md](references/interactive.md).

Open the result on Anders's machine with `open -a "Comet" <path-or-url>`. If
the work runs elsewhere, find a route that puts and opens it on his Mac. Tell
Anders the absolute Mac path or usable URL.
