---
name: html-4
description: Create a minimal question-first browser artifact from Anders's observed preferences.
disable-model-invocation: true
---

# HTML 4: empirical minimalist

Status: tournament candidate.

Start with the question the reader needs answered. Choose the smallest useful
visual form, then make one browser artifact that answers it without requiring
Anders to prescribe the layout.

Lead with the answer or dominant figure. Follow with the comparisons or causes
that explain it. Keep evidence, provenance, uncertainty, and caveats beside the
claims they qualify.

Use concrete audience-facing titles and labels. State the period, quantity,
subject, or finding rather than implying it. Annotate what the reader should
notice. Match detail to the question: broad system questions usually need
file-to-file or module-to-module flow; runtime questions may need method order.

Favor minimal light surfaces, clear hierarchy, consistent typography, and
restrained semantic color. Make useful URLs clickable wherever a source, named
item, or supporting claim has a destination.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself. It owns quantitative judgment; this skill owns the
page, verification, and handoff.

Prefer one directly openable HTML file with no build step. Keep a project
deliverable with its project and an ephemeral explanation in the OS temp or
harness visualization directory.

Open the result for Anders on his Mac. On the Mac, run
`open -a "Comet" <path-or-url>`. From another machine, establish a usable Mac
route and open that URL in Comet. Return the absolute path or usable URL.

Inspect the rendered artifact at desktop and narrow widths. Check reading
order, clipping, overflow, source links, browser errors, and every relied-on
interaction. For loading or live state, inspect the route to the final frame.
Done when the opened artifact visibly answers the original question and the
rendered result works.
