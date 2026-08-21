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

Specify the return state in the content contract: chosen values plus the
minimum identifiers needed to act. Choose Markdown for prose-shaped outcomes,
compact JSON for structured state, and TSV for tabular state. Also specify the
expected behavior of each control so the renderer can verify the journey.
