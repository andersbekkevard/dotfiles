# Interactive decision surfaces

Use this branch when the page exists so Anders can make a decision in the
browser and return it to the conversation.

Give the artifact one analytical purpose: triage this list, choose these flags,
rank these options, or tune this prompt. Use few controls, each changing the
analysis or selection that depends on it. Keep a current-state summary visible
and meaningful out of context. Show the overview first and supporting evidence
on demand without moving Anders away from his current focus.

Treat the page as a disposable decision surface, not an application. It needs
no accounts, settings, or persistence beyond the page.

The return channel is one copy button that serializes the current state to
the clipboard: chosen values plus the minimum identifiers needed to act, never
the page or the full option catalog. Choose Markdown for prose-shaped outcomes,
compact JSON for structured state, and TSV for tabular state, and name the
format beside the button. Use `navigator.clipboard.writeText` with a
hidden-textarea `execCommand` fallback, because the clipboard API fails on
`file://` in some browsers; show a brief copied state. Each control changes the
state that depends on it, not merely its label, and updates preserve keyboard
focus and the current selection. The clipboard is the whole channel; a
listener, local server, or publishing hook appears only when the task
explicitly needs one.
