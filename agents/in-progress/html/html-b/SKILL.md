---
name: html-b
description: Create a purpose-built visual HTML artifact.
disable-model-invocation: true
---

# HTML B

Status: work in progress.

This is an independent candidate for Anders's HTML workflow. Judge it by the
artifacts it produces. Tighten it only when repeated use reveals a stable
preference or failure.

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

## Verify and hand off

Render the actual file before presenting it. Check a wide viewport near 1440px
and a narrow viewport near 390px. Exercise controls, inspect browser errors,
and check clipping, horizontal overflow, keyboard focus, source links, and
readability. Scan the artifact for secrets or private payloads before opening
or sharing it.

Open the result on Anders's Mac for an interactive user-requested artifact. If
the current host is the Mac, run `open <absolute-path>`. If it is not, read
[`personal-edge`](../../skills/personal-edge/SKILL.md), use its Mac operations
lane to place and open the file there, and verify the Mac-side result. Skip
opening only when Anders asks, the run is explicitly background or bulk work,
or Mac access is unavailable. State the reason in the last case.

Report the absolute path on Anders's Mac. The work is done when the artifact
exists there, the relevant checks pass, and the file has been opened or the
explicit no-open condition has been reported.

## Open questions

- A shared stylesheet or component library may improve consistency, but its
  ownership and runtime model are not settled.
- Show Me has strong code, diff, and file-tree techniques. Its relationship to
  a general semantic HTML skill remains open.
- The editorial fallback has produced a strong report once. It is evidence, not
  proof that every subject should use that style.
