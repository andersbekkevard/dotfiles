---
name: router
description: Index of the user-invoked skill set — shows every global skill, its mode, and what it is for.
---

# Router

Most global skills are user-invoked and carry no always-loaded description, so
nothing in context lists them. This skill is the index.

Run the live table (never duplicate it here):

```bash
~/dotfiles/agents/skillctl list
```

It shows every skill's name, Claude and Codex modes (model / user / off),
always-loaded token cost, and one-line description. Read the description
column to pick the right skill, then invoke it by name.

To change a skill's mode ("make grilling model-invoked for Claude", "turn
prototype off"), use `skillctl enable-model|disable-model <skill>
[claude|codex|all]` or `skillctl off|on <skill>` — frontmatter is the source
of truth and `skillctl sync` projects it to the Codex dialect.
See `~/dotfiles/agents/README.md`.
