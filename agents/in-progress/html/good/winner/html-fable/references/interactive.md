# Interactive decision surfaces

The minority branch: the page exists so Anders can make a decision in the
browser and hand the result back to the agent. Everything in `SKILL.md` still
applies; this file adds the interaction contract. Exemplars in
`agents/references/html-effectiveness/`: `18-editor-triage-board.html`,
`19-editor-feature-flags.html`, `20-editor-prompt-tuner.html`.

## Shape

- One analytical purpose per artifact: triage this list, choose these flags,
  rank these options, tune this prompt. A surface serving two decisions is two
  artifacts.
- Few controls, each meaningful. A control changes the analysis or the
  selection, and the page recomputes what depends on it — switching a grouping
  recalculates the figures, never just relabels them.
- Keep a current-state summary always visible, phrased so it makes sense
  pasted out of context.
- Overview first, details on demand (Shneiderman): native
  `<details>`/`<summary>` for supporting evidence, or a sticky `.panel` beside
  a clickable figure. Initial open state matches the likely task.
- Preserve manual focus: updates never snap Anders away from what he selected.
- A disposable control panel for this one decision, not an application. No
  persistence beyond the page, no accounts, no settings.

## Copy-back

The bridge back to the agent is one copy button (`.btn`) that serializes the
current state to the clipboard; Anders pastes it into the conversation.

- Pick the format for clarity and token efficiency, labeled next to the
  button: prose-shaped outcomes → Markdown; structured state (flags,
  rankings) → compact JSON; tabular state → TSV.
- Serialize decisions, not the page: chosen values plus the minimum
  identifiers the agent needs to act. Never echo the full option catalog.
- `navigator.clipboard.writeText` with a hidden-textarea `execCommand`
  fallback (clipboard API fails on `file://` in some browsers), and flash the
  button (`.copied` class, "Copied ✓", ~1.2s).
- Automatic round trips — listeners, local servers, publishing hooks — stay
  out of scope. The clipboard is the whole channel until real use demands
  more.

## Verification, extended

Exercise every control and check the resulting state, reset behavior, and the
actual copied output's faithfulness. Check empty, incomplete, and invalid
states when plausible. Keyboard focus visible; narrow layout deliberate.
