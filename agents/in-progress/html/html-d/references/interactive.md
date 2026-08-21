# Interactive decision surfaces

A minority branch of `html-d`: the page exists so Anders can make a decision
in the browser and hand the result back to the agent. Expected in well under
half of uses. Everything in `SKILL.md` still applies; this file adds the
interaction contract.

## Shape

- One analytical purpose per artifact: triage this list, choose these flags,
  rank these options, tune this prompt, mark up this draft. A surface that
  serves two decisions is two artifacts.
- Few controls, each meaningful. A control changes the analysis or the
  selection, and the page recomputes what depends on it — switching a
  grouping or window recalculates the figures, never just relabels them.
- Keep an explicit current-state summary always visible: what is selected,
  ranked, or set right now, phrased so it makes sense pasted out of context.
- Treat the artifact as a disposable control panel for this one decision,
  not an application. No persistence beyond the page, no accounts, no
  settings.

## Copy-back

The bridge back to the agent is a single copy button that serializes the
current state to the clipboard. Anders pastes it into the conversation.

- Choose the format for clarity and token efficiency, and say which was
  chosen next to the button:
  - prose-shaped outcomes (triage notes, rationale) → Markdown
  - structured state (flags, settings, rankings) → compact JSON
  - tabular state (many rows, few fields) → TSV
- Serialize decisions, not the page: the chosen values plus the minimum
  identifiers the agent needs to act — never the full option catalog back.
- Use `navigator.clipboard.writeText` with a hidden-textarea `execCommand`
  fallback, and flash a visible confirmation on the button.
- Automatic round trips — listeners, local servers, publishing hooks — stay
  out of scope. The clipboard is the whole channel until real use demands
  more.
