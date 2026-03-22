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

## Quality bar for docs

- Keep docs task-oriented and executable (copy/paste examples).
- State invariants explicitly (what must always be true).
- Avoid duplicate normative rules across files; link to the canonical file instead.
- Prefer concrete failure modes + remediation over vague guidance.
- Keep terminology stable (`minimal`, `full`, `macos`, `linux-headless`, `linux-desktop`).

## Commit hygiene

- Keep changes scoped (`fix:`, `docs:`, `refactor:` etc.).
- If behavior changes but docs do not, that is a bug.
- If docs change behavior claims without code changes, justify clearly in commit message.
