---
name: html
description: Create a clear browser artifact from the current material.
disable-model-invocation: true
---

# HTML

Status: work in progress.

Turn the current material into the clearest useful browser artifact. Own both
what to show and how to show it. Anders should normally be able to invoke this
skill without first choosing a layout, diagram type, or interaction model.

## Compose

Start with the question the reader needs answered, then choose the smallest
visual form that answers it. Let the subject shape the page rather than pouring
every subject into one house layout.

Give the page a reading order. Lead with the answer or dominant visual, follow
with the comparisons or causes that explain it, and keep evidence, provenance,
and caveats beside the claims they qualify.

Use concrete titles and labels that state the period, quantity, subject, or
finding. Annotate what the reader should notice instead of making them decode
the figure. Match the abstraction to the question: a system route usually
needs file-to-file or module-to-module flow, while a runtime question may need
method-level detail.

Favor minimal, light surfaces, generous whitespace, consistent typography,
and restrained semantic color. Use sections with distinct communicative jobs;
use cards only when they express real grouping. Make URLs clickable wherever a
source, named item, or supporting claim has a useful destination.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself. Keep its quantitative judgment in that skill rather
than reproducing it here. This skill still owns the page composition,
implementation, provenance, verification, and handoff.

Read [visual forms](references/visual-forms.md) when choosing among diagrams,
comparisons, annotated figures, timelines, code or diff views, and editorial
reports. Read [interactive artifacts](references/interactive-artifacts.md) only
when selection, filtering, triage, tuning, or details on demand would materially
improve the user's journey.

## Build and hand off

Prefer one directly openable HTML file with no build step. Choose its location
from its lifecycle: keep a repository deliverable with its project; keep an
ephemeral explanation in the OS temp directory or the harness's visualization
directory. Use plain HTML, CSS, and JavaScript by default. Tailwind or Mermaid
via CDN are acceptable when network access is part of the viewing context;
inline CSS, JavaScript, and SVG when offline or durable rendering matters.

Open the result for Anders on his Mac. When already on the Mac, use
`open -a "Comet" <path-or-url>`. From another machine, establish a usable route
to the Mac, such as a loopback server and port forward, then open that URL in
Comet. Return the absolute path or usable URL.

Inspect the rendered artifact at a normal desktop width and a narrow width.
Check reading order, clipping, overflow, typography, source links, browser
errors, and every interaction the artifact relies on. For loading, animation,
or live state, inspect the route to the final state as well as the final frame.

Done when the opened artifact answers the original question visually, its
important evidence and controls work, and the actual rendered result has been
checked.
