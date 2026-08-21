---
name: html-c
description: Create a clear local HTML artifact for visual explanation or structured decisions.
disable-model-invocation: true
---

# HTML C

Status: work in progress.

Create one browser artifact that makes the subject easier for Anders to
understand or act on. The work is visual communication first and web styling
second. Derive the composition from the material instead of pouring prose into
a fixed report template.

## Choose the job

- For explanation, comparison, code, flows, or a visual report, read
  [visual-communication.md](references/visual-communication.md).
- For selection, triage, toggles, tuning, ranking, or feedback, read
  [interactive-decisions.md](references/interactive-decisions.md).
- Read both when the artifact explains the choices and collects Anders's
  decision.

For a task whose core is quantitative, keep `tufte-viz` as the specialist.
Read [`tufte-viz`](../../skills/tufte-viz/SKILL.md) and apply its quantitative
judgment rather than reimplementing it here.

## Artifact contract

Ground the artifact in the supplied material. Preserve exact labels, evidence,
and uncertainty. Put source links beside the claims or named projects they
support, not only in a footer.

Write a fresh single-file HTML artifact outside the repository unless Anders
asks for a project file. On Anders's Mac, resolve the temporary directory from
`${TMPDIR:-/tmp}` and use a descriptive, timestamped filename. A file opened on
another host does not satisfy the handoff. If the work runs remotely, find the
available route to place and open the artifact on Anders's Mac.

Tailwind through its CDN and Mermaid through its CDN are accepted tools for
local artifacts. Use Mermaid when relationships are graph-shaped and automatic
layout helps. Use HTML, CSS, and inline SVG when the composition or annotation
needs tighter control. Keep task-specific JavaScript in the file. Adapt when
offline, privacy, or project constraints require local dependencies.

Verify the result in a wide and narrow viewport. Exercise every control. Check
focus states, clipping, horizontal overflow, source links, and browser errors.
For interactive artifacts, also verify the copied output.

Open the finished file on Anders's Mac with the CLI and report its absolute Mac
path. Skip opening only when Anders asks, the work is explicitly background or
bulk work, or opening the material would expose something sensitive.

## Current boundaries

`html-c` does not absorb the surrounding workflow. Show Me remains a separate,
technical visual-explanation skill. Its code-tree and diff patterns are useful
sources, but this skill must also handle plans, research, decisions, and other
non-code subjects at their natural level of abstraction.

The first version uses clipboard export instead of a listener or automatic
browser-to-agent channel. A shared stylesheet or component library remains an
open design question. Design-variant matrices and slider-heavy exploration are
available when the task is design work, not a default part of ordinary HTML
artifacts.

Done when the artifact communicates the intended point or captures the intended
decision, every visible control and source link works, the copied result is
faithful when present, and Anders has the opened file plus its absolute path.

For the evidence and borrowed ideas behind this candidate, see
[provenance.md](references/provenance.md).
