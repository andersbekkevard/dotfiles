---
name: html
description: Render a supplied visual or page specification as self-contained HTML, verify it, and open it on Anders's Mac.
---

# HTML

One responsibility: render a supplied visual or page specification as a single
HTML file and put it open in front of Anders. Preserve the supplied form,
content hierarchy, evidence, links, caveats, and interaction contract.

## Visual language

[assets/page.css](assets/page.css) is the house language. Inline the whole file
into the artifact's `<style>` block and add page-specific rules after it.
[assets/skeleton.html](assets/skeleton.html) demonstrates the component markup;
start from it and remove what the specification does not need.

Tokens are fixed; composition follows the supplied specification. Extend with
page-specific CSS and SVG when necessary while keeping one semantic meaning per
hue. Preserve every supplied source link at the point where the content relies
on it.

## Render

Build one self-contained `.html` file with no build step and with the real
names and data supplied. Mermaid via CDN is appropriate when automatic graph
layout serves the specified relationship. Use hand-built SVG when placement,
emphasis, or direct annotation carries the meaning. Everything else inlines.

When the specification includes controls or copy-back, read
[references/interactive.md](references/interactive.md). Write outside the
repository unless the HTML is a project deliverable: use `${TMPDIR:-/tmp}` and
a descriptive timestamped filename.

## Verify and deliver

Verify the rendered artifact at wide (~1440px) and narrow (~390px) widths: no
horizontal page overflow, no console errors, every supplied link resolves, and
every relied-on interaction works. For loading or live state, test the route to
the final state rather than only the final frame.

Open it from the CLI. The artifact is not delivered until it is open on
Anders's Mac. Report the absolute path on the Mac.

Done when the supplied specification is rendered faithfully, the checks pass,
and the artifact is open in front of Anders.

## Provenance

The house language derives from
[anthropics/html-effectiveness](https://github.com/anthropics/html-effectiveness),
Thariq Shihipar's *The unreasonable effectiveness of HTML*, selected Matt
Pocock report mechanics, and visual work Anders has accepted. Editorial and
quantitative judgment live in the calling skill; this skill owns the browser
medium.
