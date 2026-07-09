# agents/ — global agent surface

One copy of every cross-repo agent instruction artifact, for both Claude Code
and Codex. Repo-specific skills stay in each repo's `.agents/skills/`.

- `AGENTS.global.md` — global working rules. Symlinked to `~/.claude/CLAUDE.md`
  and `~/.codex/AGENTS.md` (one file, two harness names).
- `skills/<name>/` — canonical global skills. `~/.claude/skills/<name>` and
  `~/.codex/skills/<name>` get per-skill symlinks so user, third-party, and
  Codex-managed `.system/` skills survive beside them.
- `archive/<name>/` — retired skills, kept whole but unlinked from every
  harness and excluded from all skill tooling. `archive/README.md` owns the
  archive/restore procedure.
- `skillctl` — invocation-state tool. Machine-level wiring is done by
  `setup/agents.sh` (minimal profile); `skillctl sync` only handles the
  Codex-generated projection.
- `skilltokens` — exact tiktoken report for skill descriptions and `SKILL.md`
  bodies, used to prune context load and sprawl.
- `skill-sources.toml` + `skillpull` — source/provenance map and read-only
  upstream drift audit for skills that are copied from or tracked against
  public remotes.

## Setup and Repair

Use setup for the machine-level agent surface:

```bash
./setup.sh --layer minimal --skip-install
```

That command skips package/runtime installers but still runs `setup/agents.sh`,
which creates or repairs `~/.claude/skills/<name>`, `~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`, and the Codex-generated skill projection. On a fresh
machine that still needs packages, run the normal explicit profile instead.

Do not use direct `agents/skillctl sync` as full agent setup. It does not create
Claude per-skill symlinks or the top-level harness instruction symlinks.

## Main flow

The engineering skills compose into one idea → ship pipeline. Everything an
effort produces lives in **one home**: `docs/prd/<effort-slug>/`.

1. **`/wayfinder`** — entry point for big, foggy efforts. Charts
   `docs/prd/<effort-slug>/` (`map.md` + investigation tickets), worked one
   ticket per session until the way is clear. A feature you can already state
   sharply skips this and starts at **`/grill-with-docs`** (grilling +
   domain-modeling, leaving `CONTEXT.md`/ADRs behind).
2. **`/to-prd`** — synthesizes the decisions into
   `docs/prd/<slug>/<slug>-prd.md` (test seams agreed with the user; slugged
   basename, vault-safe) and publishes a beads umbrella epic whose slug
   matches the folder.
3. **`/to-issues`** — slices the PRD into tracer-bullet child epics with
   native dependency edges; `br ready` surfaces unblocked slices.
4. **`/implement`** — one fresh session per slice: claim (the lock), `/tdd`
   at the pre-agreed seams, `review-changes` on completion (its Spec axis
   reads the same PRD), commit, close with evidence.

`/handoff` bridges sessions anywhere in the flow. The `beads` skill is the
substrate reference (CLI + concurrency invariants) the flow skills point at;
label taxonomy and sync rules stay repo-owned. Standalone craft skills
(`/tdd`, `/diagnosing-bugs`, `/prototype`) also run outside the pipeline.

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
agents/skillctl sync                  # regenerate yaml + Codex symlinks only; idempotent
```

`off` renames the file, not the directory: a dir rename can still leave a
discoverable `SKILL.md`, while a missing `SKILL.md` is skipped by every
harness. If Codex ever reads `disable-model-invocation` natively, delete the
yaml generation in `skillctl` — nothing else changes.

## Token Budget

Use `skilltokens` when iterating on the skill surface:

```bash
agents/skilltokens
agents/skilltokens --mode model
agents/skilltokens --sort description
agents/skilltokens --json
```

It reports exact `tiktoken:o200k_base` counts for:

- model-invoked description tokens;
- model-invoked name+description listing tokens;
- model-invoked full `SKILL.md` tokens;
- all full `SKILL.md` tokens.

Rows are sorted by full `SKILL.md` size by default and include feedback flags
for model-description context load and skill-body sprawl. The command
self-runs through `uv` with `tiktoken` when needed.

## Source Drift

`skill-sources.toml` is the single place to record where a global skill came
from. It distinguishes:

- `tracked` — compare local content to an upstream Git path.
- `watch` — related upstream/project to keep an eye on, but no stable diff path.
- `local` — intentionally local skill; do not search for remote drift.

Run:

```bash
agents/skillpull list
agents/skillpull validate
agents/skillpull check autoreview
agents/skillpull check --all
agents/skillpull check humanizer --diff
```

`skillpull` is read-only. A drift result means "review and port deliberately",
not "replace the local skill". Preserve notes in `skill-sources.toml` identify
intentional local behavior such as autoreview's thermonuclear review wiring.
