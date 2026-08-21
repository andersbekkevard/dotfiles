---
name: html-1
description: Create a browser artifact using a consistent Anders house style.
disable-model-invocation: true
---

# HTML 1: house style

Status: tournament candidate.

Turn the current material into a browser artifact with a recognizable Anders
visual identity. Decide what deserves to be visible and choose the form, but
express it through the same house grammar each time.

## House grammar

Use [the house stylesheet](assets/house-style.css) as the visual foundation.
Inline it into the artifact so the result remains one openable file. Extend it
only where the subject needs a form the stylesheet does not provide.

Build a clear reading order from these recurring elements:

1. A masthead that names the subject and context.
2. A large opening conclusion or question.
3. Editorial sections separated by rules and whitespace.
4. Directly annotated figures, comparisons, or exact evidence.
5. Quiet source notes and caveats beside the claims they qualify.

Use the warm paper surface, near-black text, serif display headings, sans-serif
body, monospaced labels, rust accent, and olive/clay judgment colors from the
stylesheet. Let scale, whitespace, rules, and alignment carry hierarchy. Use
boxed regions when they represent a real group, comparison, or decision.

Keep titles concrete. Label figures directly. Give each section one
communicative job. Make useful URLs clickable wherever a source, named item, or
supporting claim has a destination.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself. It owns quantitative judgment; this skill owns the
house composition and artifact delivery.

## Deliver

Prefer one directly openable HTML file with no build step. Keep a repository
deliverable with its project and an ephemeral explanation in the OS temp or
harness visualization directory.

Open the result for Anders on his Mac. On the Mac, run
`open -a "Comet" <path-or-url>`. From another machine, establish a usable Mac
route, such as a loopback server and port forward, and open that URL in Comet.
Return the absolute path or usable URL.

Inspect the rendered artifact at desktop and narrow widths. Check the visual
hierarchy, clipping, overflow, source links, browser errors, and every relied-on
interaction. Done when the opened artifact communicates the answer through the
house style and the rendered result works.
