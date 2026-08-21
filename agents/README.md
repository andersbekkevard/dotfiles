# agents/ — global agent surface

One source tree for every cross-repo agent instruction artifact, for both
Claude Code and Codex. Repo-specific skills stay in each repo's
`.agents/skills/`.

- `SHARED.global.md` — primary global working rules for both harnesses.
- `AGENTS.global.md` — Codex-only additions.
- `CLAUDE.global.md` — Claude-only additions. Setup composes the shared file
  first and the matching harness file second into `~/.codex/AGENTS.md` and
  `~/.claude/CLAUDE.md`; edit the sources, not the composed files.
- `.local/SHARED.md`, `.local/AGENTS.md`, `.local/CLAUDE.md`: optional,
  Git-ignored machine instructions. Setup appends shared local rules and then
  harness-local rules after the tracked global sources. Removing an overlay
  removes its content on the next setup run.
- `skills/<name>/` — canonical active global skills in one flat, auditable
  namespace. Skill names are globally unique. Setup projects them to immediate
  children at `~/.claude/skills/<name>` and
  `~/.codex/skills/<name>`. Per-skill symlinks let root-level user and
  third-party skills plus Codex-managed `.system/` skills survive beside them.
- `in-progress/<name>/` — candidate skills under deliberate development. They
  are excluded from `skillctl`, `skilltokens`, and harness installation. Test
  one by explicitly asking an agent to read its `SKILL.md`. `skillpull` still
  validates its provenance entry. Promotion moves it into `skills/<name>/`.
- `skills/.local/<name>/` — machine-specific global skills. Git ignores this
  namespace, while setup projects it to `~/.claude/skills/<name>` and
  `~/.codex/skills/<name>`. `skillctl` and `skilltokens` include it;
  `skillpull` excludes it because it is not repository provenance.
- `archive/<name>/` — retired skills, kept whole but unlinked from every
  harness and excluded from all skill tooling. `archive/README.md` owns the
  archive/restore procedure.
- `skillctl` — invocation-state tool. Machine-level wiring is done by
  `setup/agents.sh` (minimal profile); `skillctl sync` only handles the
  Codex-generated projection.
- `instructionctl`: read-only status and verification for composed global
  instructions. It reports source presence without printing private local
  content. `setup.sh agents` remains the only writer.
- `skilltokens` — exact tiktoken report for skill descriptions and `SKILL.md`
  bodies, used to prune context load and sprawl.
- `skill-sources.toml` + `skillpull` — source/provenance map and read-only
  upstream drift audit for skills that are copied from or tracked against
  public remotes.

## Setup and Repair

Use setup for the machine-level agent surface:

```bash
./setup.sh agents
```

That command runs only `setup/agents.sh`. It creates or repairs
`~/.claude/skills/<name>`, composes
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, and refreshes the flat Codex
skill projection. It does not install packages, restow unrelated dotfiles,
refresh shell templates, or update stable command entrypoints. On a fresh
machine that still needs packages, run the normal explicit profile instead.

Machine-local instruction overlays use these optional paths:

```text
agents/.local/SHARED.md
agents/.local/AGENTS.md
agents/.local/CLAUDE.md
```

The two independent choices are storage and harness:

| Storage | Both harnesses | Codex only | Claude only |
|---|---|---|---|
| Git-synced | `SHARED.global.md` | `AGENTS.global.md` | `CLAUDE.global.md` |
| Machine-local | `.local/SHARED.md` | `.local/AGENTS.md` | `.local/CLAUDE.md` |

Create only the local files this machine needs. The tracked templates are safe
starting points:

```bash
mkdir -p agents/.local
cp agents/templates/local-instructions/SHARED.md agents/.local/SHARED.md
# Or copy AGENTS.md or CLAUDE.md for one harness only.
$EDITOR agents/.local/SHARED.md
./setup.sh agents
agents/instructionctl verify
```

Setup composes tracked shared, tracked harness, local shared, then local
harness. Keep machine paths, installed application names, host capabilities,
and machine-specific access rules in the local files. Move a rule into the
tracked source once it should apply on every machine. The local directory is
Git-ignored and has no tracked placeholder.

Use `agents/instructionctl status` to inspect source state without checking the
private files into Git or printing their contents. `verify` exits nonzero when
either generated target is missing or stale. Repair it with `./setup.sh agents`.

[OpenAI's AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md/)
states that Codex gives `~/.codex/AGENTS.override.md` precedence over
`AGENTS.md`. Reserve that native file for a deliberate temporary replacement;
the additive machine-local path in this repo is `agents/.local/AGENTS.md`.

Do not use direct `agents/skillctl sync` as full agent setup. It does not create
Claude per-skill symlinks or compose the top-level harness instructions.

## Main flow

Planning is conversation-first; artifacts exist for readers, not for stages.

1. **Talk** — a plain conversation (or `/grilling`)
   builds the shared understanding. No skill required to plan.
2. **Land** — `wayfinder` makes it durable: the effort's Markdown `map.md` is the
   current-intent register (append-only decision index, fog, supersessions).
   Markdown tickets exist only for questions that must outlive the session;
   big foggy efforts get charted and worked as a map across sessions.
3. **Compile, reader-gated** — `/to-spec` publishes the full spec as a beads
   umbrella epic when ownership will cross a context boundary (big-ownership
   handoff, blind verification); `/to-tickets` turns it into claimable execution.
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
collector of the repo's shared memory; `/dream` proposes instruction-surface
edits from observed historical behavior.

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

`skill-sources.toml` is the single place to record where an active or
in-progress global skill came from. It distinguishes:

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
Machine-specific skills under `skills/.local/` do not belong in this manifest.
In-progress skills do belong because provenance should survive incubation.
