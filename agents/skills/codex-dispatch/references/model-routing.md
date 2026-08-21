# Codex model routing

Read this reference only when Anders did not name a model and the
`gpt-5.6-terra` / `high` default in `SKILL.md` is not a clear fit. Apply every
rule that bears on the choice, then return to the dispatch flow.

## Route by work shape

| Work shape | Model | Effort |
|---|---|---|
| High-volume, routine, or mechanical work | `gpt-5.6-luna` | `high` |
| Scoped implementation or ordinary investigation | `gpt-5.6-terra` | `high` |
| High-judgment analysis, design review, or synthesis | `gpt-5.6-sol` | `medium` |
| Difficult or high-stakes judgment | `gpt-5.6-sol` | `high` |

Use judgment at the boundary. Quality is the primary constraint; cost breaks
ties. If a cheaper model misses the bar, resume or rerun with the next stronger
route.

## Keep ownership with the orchestrator

The orchestrator owns architecture, integration, verification, and closeout.
Give Codex a bounded question or work package with exact paths, constraints,
acceptance criteria, and a concrete return format. Treat its result as evidence
to judge, not direction to follow.

Use multiple lanes only when their write surfaces and decisions are independent.
Serialize shared files, schema changes, architectural choices, and prerequisites.
