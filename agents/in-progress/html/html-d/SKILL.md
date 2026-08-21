---
name: html-d
description: Design and deliver a standalone HTML artifact. Use when Anders asks for an HTML page, report, comparison, or explainer, or when spatial structure, annotated figures, or an in-browser decision would communicate better than Markdown.
---

# HTML artifacts

Status: work in progress. This records Anders's current preferences plus the
few procedures that have earned confidence. Unsettled choices stay visible
under Open questions instead of becoming rules.

One responsibility: turn one body of thinking into a single HTML file that
communicates it visually, and put that file in front of Anders. Chart and
dashboard design for clearly quantitative work belongs to `tufte-viz`; quick
inline conversational visuals belong to `show-me`. Either may hand
construction to this skill; this skill also works standalone.

## Decide what to show

This is the load-bearing step. The page is an argument, not a transcript of
the work. Before writing any HTML:

1. Name the few claims the page exists to make. Each major section carries
   one of them, and its heading states the claim ("Mine these. Do not merge
   them."), not the category ("Analysis").
2. For each claim, pick the form that makes its relationship visible:
   - things compete or differ → side-by-side columns, a take/leave pair, a
     small matrix
   - things depend, call, or flow → a graph or sequence diagram
   - placement and emphasis carry the point → a hand-built figure with
     annotations sitting on the figure itself
   - order matters → a timeline or numbered sequence
   - the reader may want depth → conclusion first, details on demand
     (`<details>`, tabs, click-to-reveal)
3. Lead with the finding. Put each caveat beside the evidence it qualifies.
   End a decision-shaped page with the questions Anders should now be able
   to answer.

Let the subject's shape choose the layout. A page of uniform stacked cards
means the content's shape hasn't been found yet — return to step 2. Show the
meaningful files, modules, numbers, and entities; the parts of a call stack
or dataset that don't bear on a claim stay off the page.

## Sources stay clickable and close

Wherever a URL exists — repository, document, post, ticket — make the name
or claim a link, placed where the claim relies on it. A page whose sources
appear only in a footer has failed this rule.

## Visual language

The target is the editorial clarity of Anthropic's html-effectiveness
gallery, as a direction rather than a fixed stylesheet:

- Editorial hierarchy: display headings (serif works well), restrained body
  type, generous whitespace, a single readable column with room for asides.
- Semantic color: a warm neutral ground plus a few hues that each mean one
  thing across the whole page (for example olive = adopt, rust = leave,
  red = problem). Color states meaning; grayscale carries everything else.
- Direct labels and annotations on figures; a legend only when direct
  labeling fails.
- Mono or small-caps eyebrows for section metadata, never for content.

## Construction

- One self-contained `.html` file with real names and data from the actual
  subject. Tailwind and Mermaid via CDN are acceptable; inline everything
  else.
- Mermaid for graph-shaped relationships. Hand-built SVG or styled divs when
  exact placement and annotation carry the meaning — Mermaid's layout goes
  generic there.

## Delivery

- Write the file outside the working repository (a temp or artifacts
  directory) unless Anders asks otherwise.
- The artifact is delivered when it is open on Anders's Mac, not merely on
  the machine that ran the agent. Locally: `open <absolute path>`. From a
  remote host, first move the file somewhere the Mac can open (mechanism
  unsettled — see Open questions). Always report the absolute path on the
  Mac.
- Verify in a browser-realistic pass before handing over: wide and narrow
  widths, no horizontal overflow, no console errors, links work.

## Interactive artifacts

Most artifacts are read, not operated. When Anders should make a decision in
the browser — triage, ranking, flag selection, prompt tuning, annotating —
read [references/interactive.md](references/interactive.md) for the
decision-surface shape and the copy-back contract.

## Open questions

- Whether CDN dependence should stay the default or an offline-safe single
  file should be, once artifacts get archived or opened without network.
- Whether a small copy-in stylesheet or token set is worth maintaining, or
  consistency should keep emerging from the visual-language section alone.
- The concrete remote-host → Mac delivery mechanism.
- Which recurring forms (code and diff treatment first) deserve their own
  reference files once use shows they repeat.
