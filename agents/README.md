# agents/ — global agent surface

One copy of every cross-repo agent instruction artifact, for both Claude Code
and Codex. Repo-specific skills stay in each repo's `.agents/skills/`.

- `AGENTS.global.md` — global working rules. Symlinked to `~/.claude/CLAUDE.md`
  and `~/.codex/AGENTS.md` (one file, two harness names).
- `skills/<category>/<name>/` — canonical global skills, grouped for overview:
  `flow/` (planning surface + beads substrate), `engineering/` (craft +
  review), `fleet/` (orchestration/delegation), `meta/` (the system that
  maintains the system), `desk/` (personal utilities + format references).
  Skill names are globally unique; `~/.claude/skills/<category>/<name>` and
  `~/.codex/skills/<category>/<name>` mirror the canonical categories with
  per-skill symlinks so root-level user and third-party skills plus
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
which creates or repairs `~/.claude/skills/<category>/<name>`, `~/.claude/CLAUDE.md`,
`~/.codex/AGENTS.md`, and the Codex-generated skill projection. On a fresh
machine that still needs packages, run the normal explicit profile instead.

Do not use direct `agents/skillctl sync` as full agent setup. It does not create
Claude per-skill symlinks or the top-level harness instruction symlinks.

## Main flow

Planning is conversation-first; artifacts exist for readers, not for stages.

1. **Talk** — a plain conversation (or `/grilling` / `/grill-with-docs`)
   builds the shared understanding. No skill required to plan.
2. **Land** — `wayfinder` makes it durable: the effort's map issue is the
   current-intent register (append-only decision index, fog, supersessions).
   Tickets only for questions that must outlive the session; big foggy
   efforts get charted and worked as a map across sessions.
3. **Compile, reader-gated** — `/to-spec` publishes the full spec as a beads
   umbrella epic when ownership will cross a context boundary (big-ownership
   handoff, blind verification); `/to-tickets` turns it into claimable work.
   One child may carry the whole spec, or several may expose a frontier.
   Neither reader coming → the map's decisions are the spec.
4. **Execute** — claim (the lock, per the `beads` skill), work at the
   pre-agreed seams, review against the same spec on completion (builtin
   /code-review or codex review), commit, close with evidence. The
   implementer never self-certifies big-ownership work — a fresh context
   grades it against the spec.

`/handoff` bridges sessions anywhere. The `beads` skill is the substrate
reference (CLI + concurrency invariants) the flow skills point at; label
taxonomy and sync rules stay repo-owned. `/lint` is the scheduled garbage
collector of the repo's shared memory; `/reflect` + `/dream` are the learning
loop that proposes instruction-surface edits from observed behavior.

## Invocation modes

Frontmatter in `SKILL.md` is the source of truth. Claude reads
`disable-model-invocation`; `disable-codex-model-invocation` optionally
overrides Codex, whose `agents/openai.yaml` policy is generated. Never edit a
generated policy block; hand-authored `interface:` metadata is preserved.

```bash
agents/skillctl list                  # effective Claude + Codex modes
agents/skillctl disable-model <s> codex
agents/skillctl enable-model <s> claude
agents/skillctl disable-model <s>     # defaults to all harnesses
agents/skillctl off <s> / on <s>      # renames SKILL.md ↔ SKILL.off.md (invisible everywhere)
agents/skillctl sync                  # regenerate yaml + Codex symlinks only; idempotent
```

`off` renames the file, not the directory: a dir rename can still leave a
discoverable `SKILL.md`, while a missing `SKILL.md` is skipped by every
harness. Omitting the harness from `enable-model` or `disable-model` changes
both; targeting one preserves the other's effective state.

## Token Budget

Use `skilltokens` when iterating on the skill surface:

```bash
agents/skilltokens
agents/skilltokens --harness codex
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
