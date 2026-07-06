# agents/ — global agent surface

One copy of every cross-repo agent instruction artifact, for both Claude Code
and Codex. Repo-specific skills stay in each repo's `.agents/skills/`.

- `AGENTS.global.md` — global working rules. Symlinked to `~/.claude/CLAUDE.md`
  and `~/.codex/AGENTS.md` (one file, two harness names).
- `skills/<name>/` — canonical global skills. `~/.claude/skills` is a whole-dir
  symlink here; `~/.codex/skills/<name>` gets a per-skill symlink (so
  Codex-managed `.system/` survives beside them).
- `skillctl` — invocation-state tool. Wiring is done by `setup/agents.sh`
  (minimal profile).

## Invocation modes

Frontmatter in `SKILL.md` is the source of truth; the Codex dialect
(`agents/openai.yaml` with `policy: allow_implicit_invocation: false`) is
generated — never hand-edit policy blocks (hand-authored `interface:` metadata
is preserved).

```bash
agents/skillctl list                  # every skill: mode, token cost, description
agents/skillctl disable-model <s>     # model → user (adds frontmatter flag, syncs yaml)
agents/skillctl enable-model <s>      # user → model
agents/skillctl off <s> / on <s>      # renames SKILL.md ↔ SKILL.off.md (invisible everywhere)
agents/skillctl sync                  # regenerate yaml + Codex symlinks; idempotent
```

`off` renames the file, not the directory: a dir rename can still leave a
discoverable `SKILL.md`, while a missing `SKILL.md` is skipped by every
harness. If Codex ever reads `disable-model-invocation` natively, delete the
yaml generation in `skillctl` — nothing else changes.
