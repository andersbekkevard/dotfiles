# AGENTS.md

This file is the navigation map for coding agents working in this repo.

## Mission

Maintain a durable cross-platform dotfiles management CLI (`dotfiles.sh`) with explicit mutation boundaries, predictable profile behavior, and verifiable outcomes.

Operator invariant: `./dotfiles.sh` is the only root management entrypoint. Files under `setup/` are internal implementation files or maintenance helpers unless a doc explicitly says otherwise.

## Git continuity

This repository is the durable cross-machine project record. At the start of
every turn, inspect the working tree and branch. When the tree is clean, pull
the tracked branch with `git pull --ff-only` before other repository work. If it
is dirty or diverged, preserve the existing work and reconcile it without
reset, overwrite, or an implicit stash.

After every turn that changes durable project state, review the diff, run the
relevant checks, stage only the task's files, commit, reconcile remote changes,
and push before replying to Anders. Verify that the intended commit exists on
the remote. Do not create empty commits. If synchronization fails, leave the
work recoverable and report the local commit, branch, and exact failure.

## Mandatory read order (before editing code)

1. `README.md` (repo overview + quick start)
2. `docs/usage.md` (operator workflows and safe commands)
3. `docs/profiles.md` (explicit profile semantics and boundaries)
4. `docs/runtimes.md` (runtime contracts + minimum versions)
5. `docs/architecture.md` (repo layout and layer model)
6. `setup/lib.sh` + relevant `setup/*.sh` layer files for the change

If the task touches secrets, also read:
- `docs/secrets.md`

## Private repository content

Anders-private repository content includes:

- shell secrets;
- skill-use evidence and usage batches;
- private MCP registries;
- complete Anders-specific operational skills;
- private skill snapshots;
- machine registries and verified host identities; and
- benchmark cases reconstructed from Anders's real sessions.

`.gitattributes` is the authoritative exact path list. Reusable procedures,
runners, and sanitized examples remain public.

Before committing any protected content, verify the staged Git blobs rather
than trusting the attribute declaration:

```bash
agents/git-crypt-check staged -- <paths...>
```

Do not commit if the check fails. After committing, verify the resulting tree
with `agents/git-crypt-check tree HEAD -- <paths...>`. After pushing, verify the
remote with `agents/git-crypt-check tree origin/main -- <paths...>`.

When Anders identifies a new file, directory, or category as private, add its
exact path to `.gitattributes` before staging the content. Add a new semantic
category to this inventory when needed, and add a representative path to
`agents/tests/test_private_content_policy.py` in the same commit.

## Documentation map (source-of-truth matrix)

| File | Primary purpose | Source of truth for |
|---|---|---|
| `README.md` | Entry point for humans and quick bootstrap | First-run workflow, explicit profiles, and high-level guarantees |
| `docs/README.md` | Documentation landing page | Fast entrypoint for browsing the docs directory |
| `docs/index.md` | Documentation directory map | Where each topic lives |
| `docs/usage.md` | Day-to-day dotfiles operation | How to run, verify, stow, and customize dotfiles itself |
| `docs/profiles.md` | Profile behavior | Explicit profile selection and boundaries |
| `docs/runtimes.md` | Runtime/toolchain policy | Version floors and installer strategy |
| `docs/architecture.md` | Structural model | Stow layout, layering, ownership boundaries |
| `docs/local-overrides.md` | Machine-local customization | Shell, command, and global agent override ownership |
| `docs/secrets.md` | Secrets handling | `git-crypt` unlock/export flow |
| `docs/design-principles.md` | General engineering philosophy | Cross-project standards (not bootstrap behavior) |
| `agents/README.md` | Global agent surface (skills, skillctl, wiring) | Skill invocation-state system and harness composition contract |

## Agent Surface Setup

If a task asks to set up, repair, or refresh global agent skills or global
agent instructions on the current machine, use setup, not direct `skillctl`:

```bash
./dotfiles.sh agents sync
```

This is the narrow machine-repair path for the agent surface. It runs
`setup/agents.sh` without package or runtime installers, dotfile restows, local
template refreshes, or stable command-entrypoint updates. It creates or repairs
`~/.claude/skills/<name>`, composes `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md` from the primary shared instructions plus their harness
additions, and invokes `agents/skillctl sync` for Codex-generated state.

Use the normal first-run profile command (`./dotfiles.sh install macos`,
`./dotfiles.sh install linux-desktop`, `./dotfiles.sh install full`, or
`./dotfiles.sh install minimal`) on a new machine that still needs packages or
runtimes. `install` fills missing prerequisites without upgrading working
providers; use `./dotfiles.sh update <profile>` for deliberate managed
upgrades. Both require confirmation. In a no-prompt run, pre-authenticate sudo
rather than relying on a subordinate prompt.

Use direct `skillctl` only when the machine-level harness surface already exists
and the task is specifically to regenerate Codex dialect metadata from
`SKILL.md` frontmatter:

```bash
agents/skillctl sync
```

Direct `skillctl sync` does not create Claude per-skill links or compose
top-level harness instructions; treating it as full agent setup is a bug.

## Update rules

When behavior changes, update docs in the same commit:

- **CLI flow changes** (`dotfiles.sh` commands, flags, verify behavior) → update `docs/usage.md`
- **Tool usage docs** for tmux, Neovim, `wt`, and other installed software do **not** belong in `docs/usage.md`; keep that file focused on operating the dotfiles repo itself
- **Profile selection changes** → update `docs/profiles.md`
- **Runtime install/version policy changes** → update `docs/runtimes.md`
- **Repo/package/layer structure changes** → update `docs/architecture.md`
- **Secrets workflow changes** → update `docs/secrets.md`

Also update `README.md` if the change affects first-run expectations.

## Issue Tracking

This repo uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) via `br` for local-first issue tracking.

- Tracker data lives in `.beads/`.
- `br` is non-invasive: it never runs `git` commands for you.
- After changing issues, run `br sync --flush-only` and then stage `.beads/` manually.
- Do not edit SQLite files in `.beads/` directly.

Preferred CLI flow:

```bash
br ready
br list --status=open
br show <id>
br create "Title" --type task --priority 2
br update <id> --status in_progress
br close <id> --reason "Completed"
br sync --flush-only
git add .beads/
```

Use `br ready` at the start of work to find unblocked issues. If you discover new follow-up work during a change, capture it with `br create` instead of leaving it implicit.

## Quality bar for docs

- Keep docs task-oriented and executable (copy/paste examples).
- State invariants explicitly (what must always be true).
- Avoid duplicate normative rules across files; link to the canonical file instead.
- Prefer concrete failure modes + remediation over vague guidance.
- Keep terminology stable (`minimal`, `full`, `macos`, `linux-desktop`).
- Keep `docs/usage.md` scoped to dotfiles operations, not tutorials for bundled tools.

## Installation ordering invariant

Layer scripts (`setup/minimal.sh`, `setup/full.sh`, etc.) are dependency-ordered sequences. Every line assumes the lines above it have already succeeded. When changing installation logic, **verify the prerequisite chain before and after the change**:

- A step that downloads (curl, wget) must run after the package manager installs those tools.
- A step that adds an external apt repo must run after curl is available and before packages from that repo are installed.
- A step that parses JSON (jq) must run after jq is installed.
- `apt_update_once` caches its result; any repo added *after* the first call needs its own forced `apt-get update`.

**Before merging any change to a layer script or package manifest**, mentally (or actually) trace the sequence on a blank machine where only the base OS packages exist. Ask: "Is every tool this line uses already installed by a previous line?"

Concrete failure modes to watch for:
- `curl | tee` in a pipeline: `$?` captures tee's exit, not curl's. Check the output file is non-empty (`[[ -s "$file" ]]`) instead.
- External repo source lines missing `[signed-by=...]` will cause GPG errors on `apt update`.
- Removing a package from an apt manifest without ensuring it's installed elsewhere silently drops it.

## Commit hygiene

- Keep changes scoped (`fix:`, `docs:`, `refactor:` etc.).
- If behavior changes but docs do not, that is a bug.
- If docs change behavior claims without code changes, justify clearly in commit message.
