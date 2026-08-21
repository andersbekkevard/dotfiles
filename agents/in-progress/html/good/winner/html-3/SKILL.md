---
name: html-3
description: Create a subject-shaped editorial browser artifact using Anthropic-inspired visual communication.
disable-model-invocation: true
---

# HTML 3: editorial director

Status: tournament candidate.

Turn the current material into a visual argument. Decide what the reader should
understand, then give that subject an art direction and page structure that
makes the understanding immediate. Aim for consistent care rather than a
consistent look.

## Direct the page

Choose a dominant visual idea before choosing components. Give the page a
deliberate reading journey: a strong opening claim or question, sections that
each advance it, annotated figures that carry the explanation, and evidence or
caveats at the point where they matter.

Let typography, composition, color, and visual metaphor respond to the subject.
Use whitespace, scale, alignment, rules, and contrast as the main hierarchy.
Use color sparingly and semantically. Use containers when they reveal grouping;
let the page breathe when the relationship is spatial or narrative.

Prefer direct labels and annotations over legend hunting. Give every figure a
reason to exist and every section a distinct communicative job. Make useful
URLs clickable wherever a source, named item, or supporting claim has a
destination.

Read [the editorial repertoire](references/editorial-repertoire.md) when the
artifact needs comparisons, flows, research explanation, custom figures,
details on demand, or an interactive decision surface. Load only the branches
that match the current subject.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself. It owns quantitative judgment; this skill owns the
editorial composition and artifact delivery.

## Deliver

Prefer one directly openable HTML file with no build step and minimal external
dependencies. Keep a project deliverable with its project and an ephemeral
explanation in the OS temp or harness visualization directory.

Open the result for Anders on his Mac. On the Mac, run
`open -a "Comet" <path-or-url>`. From another machine, establish a usable Mac
route and open that URL in Comet. Return the absolute path or usable URL.

Inspect the actual page at desktop and narrow widths. Check the reading journey,
figure annotation, clipping, overflow, source links, browser errors, and every
relied-on interaction. Done when the opened page communicates through its
visual structure rather than requiring a prose explanation of the design.
