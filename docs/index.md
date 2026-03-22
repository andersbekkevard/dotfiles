# Documentation Index

Use this page as the map for the `docs/` directory.

## Start here

- New contributor / operator: `README.md` → `docs/usage.md`
- Profile behavior/debugging: `docs/profiles.md`
- Runtime/toolchain expectations: `docs/runtimes.md`
- Structural changes to repo/setup: `docs/architecture.md`

Operator invariant:

- The only root bootstrap entrypoint is `./setup.sh`.
- Files under `setup/` are internal helpers, manifests, and maintenance tools unless a doc explicitly says otherwise.

## Topic map

| Topic | Canonical file | Notes |
|---|---|---|
| Daily usage, verify, maintenance | `docs/usage.md` | Operational commands, explicit profiles, and the single entrypoint |
| Profiles and selection | `docs/profiles.md` | Explicit profile choices and boundaries |
| Runtime version and installer policy | `docs/runtimes.md` | Version floors and installer strategy |
| Repository/layer architecture | `docs/architecture.md` | Stow packages + setup orchestration |
| Local overrides and stable command layer | `docs/local-overrides.md` | Where machine-specific shell tweaks and automation-visible wrappers belong |
| Secrets and git-crypt flow | `docs/secrets.md` | Unlock/export behavior |
| Migration history and rationale | `docs/migration.md` | Historical context from old branch model |
| General engineering principles | `docs/design-principles.md` | Broader coding standards |

## Rule of one canonical owner

Each normative rule should live in one primary file.
If a second doc needs it, link to the canonical source instead of duplicating policy text.
