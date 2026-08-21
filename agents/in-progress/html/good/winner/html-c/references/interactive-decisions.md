# Interactive decisions

Read this reference when Anders should manipulate the artifact, make choices,
or return structured feedback to the agent.

## The feedback loop

Use the browser as a temporary decision tool:

1. Present the current state and the decision in one view.
2. Let Anders select, rank, move, toggle, edit, or annotate the real items.
3. Show consequences, constraints, warnings, and pending changes as the state
   changes.
4. Export the decision through a visible `Copy as Markdown` action.
5. Let Anders paste the explicit result back into the agent conversation.

This clipboard loop is the current default. It stays local, harness-neutral,
and under Anders's control. Do not add a listener, server, publisher, or
automatic session callback to the first version.

## Useful interaction forms

- A triage board groups identified items into ordered buckets and exports every
  bucket with its rationale and item IDs.
- A feature or configuration editor shows the original value, current value,
  dependency warnings, and pending diff. Offer a Markdown decision packet and,
  when useful, a domain-native diff or full JSON export.
- A prompt tuner edits one prompt while previewing it against several distinct
  examples. Copy the exact prompt text after it survives those examples.
- A choice view supports single select, multi-select, ranking, approval,
  rejection, and notes without requiring the user to transcribe labels.
- An explainer may reveal details on demand or let a selected diagram node drive
  a nearby detail panel.

Use sliders and variant matrices when the task itself is visual or parameter
design. Ordinary planning and review usually need discrete choices, notes, and
comparisons instead.

## Export the decision, not the page

The Markdown should be compact and unambiguous. Include:

- artifact title and a stable subject or version identifier;
- the choices grouped in their visible order;
- stable item IDs or source links;
- approvals, rejections, ranks, changed values, and written notes;
- warnings or unresolved conflicts that remain after the interaction.

Do not copy decorative prose, hidden UI state, or the whole document. Use a
deterministic order so two exports can be compared. If the artifact represents
changes, make the difference from the initial state explicit.

Use `navigator.clipboard.writeText` with a textarea fallback because local
`file://` pages may not receive clipboard permission. Confirm success on the
button briefly without moving the layout. Keep Reset available when the state
can diverge from its initial values.

## Interaction quality

Keep state visible. A selected item, changed flag, active detail, and unresolved
warning must look different without relying on color alone. Disable actions
that have no meaningful output. Preserve keyboard focus, labels, and sensible
tab order. Avoid drag-only controls when a click or keyboard alternative can do
the same job.

Details-on-demand follows Ben Shneiderman's information-seeking mantra:
overview first, zoom and filter, then details on demand. Use it to protect the
overview, not to hide information the decision requires.
