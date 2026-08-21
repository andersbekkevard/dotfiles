# Interactive HTML implementation

Read this only when the supplied specification includes controls, selection,
or copy-back.

Implement each specified control so it changes the dependent state, not merely
its label. Preserve keyboard focus and the user's current selection through
updates. Use native `<details>` and `<summary>` or the house `.panel` component
for specified details on demand. Keep the narrow layout deliberate and keyboard
focus visible.

When the specification calls for copy-back, provide one `.btn` that serializes
the specified state and format to the clipboard. Use
`navigator.clipboard.writeText` with a hidden-textarea `execCommand` fallback
for `file://`, then briefly show a copied state. Serialize only the decision and
the identifiers the agent needs, never the page or full option catalog.

Exercise every control and verify its resulting state, reset behavior, and
copied output. Include plausible empty, incomplete, and invalid states. The
clipboard is the complete return channel; add no listener, local server, or
publishing hook unless the specification explicitly requires one.
