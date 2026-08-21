---
name: html-b
description: Create a purpose-built visual HTML artifact.
disable-model-invocation: true
---


## Outcome

Create one browser artifact that makes the subject easier to inspect, compare,
decide, or manipulate. The artifact is the deliverable, not a decorated copy of
a Markdown report.

Before designing, read [the visual grammar](references/visual-grammar.md). If
the task is definitely quantitative, also read
[`tufte-viz`](../../skills/tufte-viz/SKILL.md) and preserve its quantitative
judgment. `html-b` still owns the final file and handoff.

## Build

1. Name the user's reading action. What should become easier after opening the
   file: understanding, comparison, selection, annotation, or tuning?
2. Choose a visual form from the subject's structure. Use the project's visual
   system when one exists. Otherwise use the editorial fallback in the visual
   grammar as a starting point, not a mandatory house style.
3. Put evidence beside the claim it supports. Link named projects, source
   documents, statistics, and findings directly. A source footer may summarize
   the corpus, but it does not replace point-of-claim links.
4. Write a single HTML file. Keep the artifact outside the repository unless
   the user asks for a workspace deliverable. On Anders's Mac, resolve the
   directory from `${TMPDIR:-/tmp}` and use a fresh descriptive filename with a
   timestamp.
5. Use interaction only when it helps the reading action. A purpose-built
   editor ends with an export such as copy as JSON, Markdown, prompt, or diff.

Tailwind and Mermaid through a CDN are accepted tools, not requirements. Use
Mermaid for graph-shaped relationships. Use HTML, CSS, and inline SVG when the
composition is editorial or Mermaid fights the intended emphasis. A single
HTML file that loads a CDN is not offline-contained; choose or disclose that
tradeoff when offline use matters.

Open the result on Anders's Mac for an interactive user-requested artifact. If
the current host is the Mac, run `open <absolute-path>`. If it is not, read
[`personal-edge`](../../skills/personal-edge/SKILL.md), use its Mac operations
lane to place and open the file there, and verify the Mac-side result. Skip
opening only when Anders asks, the run is explicitly background or bulk work,
or Mac access is unavailable. State the reason in the last case.

Report the absolute path on Anders's Mac. The work is done when the artifact
exists there, the relevant checks pass, and the file has been opened or the
explicit no-open condition has been reported.
