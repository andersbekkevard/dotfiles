---
name: suggest-a-skill
description: Rank five active skills that would help most with the current objective.
disable-model-invocation: true
---

# Suggest a skill

Take a step back from the latest instruction and identify what Anders is
actually trying to achieve in the current conversation.

## Inventory

Account for every active user- and model-invoked skill before ranking. In the
dotfiles checkout, use `agents/skillctl list` as the active catalog and read the
complete `description` from each listed skill's `SKILL.md` frontmatter; the list
display may truncate it. Exclude skills that are off, archived, in progress, or
this skill itself.

Read descriptions, not every skill body. Open a candidate's body only when its
description leaves a material ambiguity that affects the ranking.

## Rank

Prefer skills that directly improve the next move toward the broader objective.
Demote skills that are merely generally useful, duplicate another candidate's
contribution, or solve a later problem. Do not invoke or perform any recommended
skill.

Reply with one sentence stating the current objective, followed by exactly five
items in ranked order:

1. `$skill-name` — _user-invoked_ or _model-invoked_
   **Description:** the skill's complete description, verbatim.
   **Why now:** one sentence connecting it to the current objective.

Use the same structure for items 2–5. If fewer than five eligible skills exist,
list every eligible skill and say why the list is short.
