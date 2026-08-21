---
name: anders-skill-writing
description: Anders's evolving preferences for designing, importing, splitting, and revising agent skills. Use when creating or materially revising a skill in Anders's system.
disable-model-invocation: true
---

# Anders skill writing

Status: work in progress.

This skill records Anders's current preferences, not universal rules or a
finished method. A newer explicit choice from Anders takes precedence. Keep an
unsettled choice visible instead of turning an assumption into policy.

## Work on a skill

Read [`writing-for-agents`](../writing-for-agents/SKILL.md) for instruction
mechanics, including context pointers, information hierarchy, invocation,
completion criteria, and pruning. Apply those mechanics in proportion to the
skill's maturity rather than using every available technique by default.

Before editing, identify:

- the skill's coherent responsibility;
- whether it mainly records a preference, a procedure, or a necessary mixture;
- how much of its workflow Anders already understands; and
- which choices remain open.

Read [the principles](references/principles.md) when deciding any of these:

- how much behavior an initial or evolving skill should specify;
- whether responsibilities should be split, combined, or coupled; or
- how to import, adapt, or substantially rewrite someone else's skill.

Make the smallest change supported by current understanding and evidence.
Revise the existing source of truth and remove superseded guidance instead of
stacking another rule beside it. Treat a one-off result as evidence or a
hypothesis until repeated use earns a durable instruction.

## Review the result

Use these as judgment prompts, not a mechanical gate:

- Is the responsibility coherent and replaceable?
- Has each precise instruction earned its precision?
- Are preferences, tested procedures, and open hypotheses distinguishable?
- Does borrowed work retain its useful procedure, intent, and provenance?

For a skill in the global dotfiles collection, register its provenance in
`agents/skill-sources.toml`, then validate and inspect it:

```bash
agents/skillpull validate
agents/skillctl list
agents/skilltokens
```

Use `./dotfiles.sh agents sync` when the installed harness surface needs to be
created or refreshed.
