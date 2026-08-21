---
name: html-2
description: Create a technically explicit HTML report with diagrams, diffs, and verification.
disable-model-invocation: true
---

# HTML 2: technical report builder

Status: tournament candidate.

Render the current technical question as one self-contained HTML report. Make
the system, change, or recommendation inspectable through diagrams and exact
evidence rather than prose alone.

## Build the report

Identify the technical question and the ownership level it requires. Show file,
package, or module routes for broad architecture questions; use methods and
call order when runtime mechanics are the subject.

Lead with a concise answer and a visual overview. Then use the forms that expose
the relevant mechanics:

- Mermaid for dependencies, flows, sequences, and graph-shaped relationships.
- Hand-built HTML or inline SVG when automatic layout obscures grouping,
  visual weight, or annotation.
- Side-by-side before and after views for changes and alternatives.
- Syntax-highlighted code or diffs when exact lines are the evidence.
- Shallow file trees for responsibility and repository shape.
- Tables for repeated fields and exact inventories.

Keep only the nodes, edges, files, calls, and code needed to answer the
question. Label diagrams directly and place the consequence beside the
relevant visual. Make file paths and useful source URLs clickable when they
have accessible destinations.

Use Tailwind via CDN for layout and Mermaid via CDN for graph-shaped diagrams
when the viewing environment has network access. Add a small custom CSS layer
for editorial figures, annotations, code emphasis, and cases where Tailwind or
Mermaid cannot express the point. Prefer a light neutral surface, strong type
hierarchy, sparse semantic color, and readable code.

When the material is primarily quantitative, read and apply the installed
`tufte-viz` skill itself. It owns quantitative judgment; this skill owns the
technical report and delivery.

## Deliver

Write a fresh single HTML file in the OS temp directory using a descriptive
timestamped name, unless the report is itself a project deliverable. The page
must open without a build step.

Open the result for Anders on his Mac. On the Mac, run
`open -a "Comet" <path-or-url>`. From another machine, serve or forward the
artifact to a usable Mac URL and open it in Comet. Return the absolute path or
usable URL.

Inspect the rendered report at desktop and narrow widths. Verify Mermaid
rendering or its fallback, code overflow, source links, diagram labels, browser
errors, and every relied-on interaction. Done when the technical route or
change can be understood from the visuals and exact evidence in the opened
report.

## Provenance

This candidate deliberately preserves the implementation-oriented report
patterns from HumanLayer's [Show Me](https://github.com/humanlayer/skills/tree/main/plugins/show-me/skills/show-me) and Matt Pocock's [Improve Codebase Architecture](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture).
