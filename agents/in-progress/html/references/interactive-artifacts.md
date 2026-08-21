# Interactive artifacts

Use interaction when it helps Anders explore dense material or make a decision.
Keep a static reading path when the page only needs to communicate an answer.

## Details on demand

Apply Ben Shneiderman's information-seeking mantra: overview first, zoom and
filter, then details on demand. Native `details` and `summary` work well for
supporting evidence, raw records, tool traces, and explanations that would
otherwise interrupt the main reading order. Make the initial open state match
the likely task and provide collapse or expand controls when the collection is
large.

## Decision surfaces

Selection, multi-selection, ranking, triage, feature flags, and prompt tuning
work when the control and its consequence remain visible together. Use the
smallest set of controls that changes a meaningful decision. Preserve manual
focus during refreshes; live updates should not snap Anders away from what he
selected.

When the page collects a decision, provide a copy action that exports the
current state in a concise, faithful format. Choose Markdown, JSON, CSV, TSV, or
another representation according to structure and token cost. Label the format
and include a clipboard fallback that works from `file://` when practical. The
normal handoff is manual: Anders copies the state back to the agent.

## Stateful exploration

Make defaults visible. Keep controls editable when that preserves agency, and
switch modes predictably when an edit changes the meaning of a preset. If URLs
encode state, copied links, fresh loads, history navigation, and malformed
values should resolve to the same visible interpretation without URL churn from
transient UI state.

## Verification

Exercise every control and verify the resulting state, reset behavior, copied
output, keyboard focus, and narrow layout. Check empty, incomplete, and invalid
states when they are plausible. For live artifacts, inspect whether refreshes
preserve the user's selection.

## Provenance

The leading examples are Anthropic's [research explainer](https://github.com/anthropics/html-effectiveness/blob/main/14-research-feature-explainer.html), [triage board](https://github.com/anthropics/html-effectiveness/blob/main/18-editor-triage-board.html), [feature flags editor](https://github.com/anthropics/html-effectiveness/blob/main/19-editor-feature-flags.html), and [prompt tuner](https://github.com/anthropics/html-effectiveness/blob/main/20-editor-prompt-tuner.html). They demonstrate the patterns; they do not define a required component system.
