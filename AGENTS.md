# AGENTS.md

This file is the navigation map for coding agents working in this repo.

## Mission

Maintain a one-hit, idempotent, cross-platform dotfiles bootstrap (`setup.sh`) with predictable profile behavior and verifiable outcomes.

Operator invariant: `./setup.sh` is the only root bootstrap entrypoint. Files under `setup/` are internal implementation files or maintenance helpers unless a doc explicitly says otherwise.

## Mandatory read order (before editing code)

1. `README.md` (repo overview + quick start)
2. `docs/usage.md` (operator workflows and safe commands)
3. `docs/profiles.md` (explicit profile semantics and boundaries)
4. `docs/runtimes.md` (runtime contracts + minimum versions)
5. `docs/architecture.md` (repo layout and layer model)
6. `setup/lib.sh` + relevant `setup/*.sh` layer files for the change

If the task touches secrets or migration, also read:
- `docs/secrets.md`
- `docs/migration.md`

## Documentation map (source-of-truth matrix)

| File | Primary purpose | Source of truth for |
|---|---|---|
| `README.md` | Entry point for humans and quick bootstrap | First-run workflow, explicit profiles, and high-level guarantees |
| `docs/README.md` | Documentation landing page | Fast entrypoint for browsing the docs directory |
| `docs/index.md` | Documentation directory map | Where each topic lives |
| `docs/usage.md` | Day-to-day commands | How to run, verify, and maintain dotfiles |
| `docs/profiles.md` | Profile behavior | Explicit profile selection and boundaries |
| `docs/runtimes.md` | Runtime/toolchain policy | Version floors and installer strategy |
| `docs/architecture.md` | Structural model | Stow layout, layering, ownership boundaries |
| `docs/secrets.md` | Secrets handling | `git-crypt` unlock/export flow |
| `docs/migration.md` | Historical context | Why current architecture exists |
| `docs/design-principles.md` | General engineering philosophy | Cross-project standards (not bootstrap behavior) |

## Update rules

When behavior changes, update docs in the same commit:

- **CLI flow changes** (`setup.sh` flags, verify behavior) → update `docs/usage.md`
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
