# Docs README

Use this directory as the documentation hub for the dotfiles repo.

Start here:

- Repo overview and bootstrap entrypoint: `../README.md`
- Documentation map: `index.md`
- Daily operator workflow: `usage.md`
- Profile selection semantics: `profiles.md`
- Runtime and installer policy: `runtimes.md`
- Repo/package architecture: `architecture.md`

## Beads Workflow

This repo uses [beads_rust](https://github.com/Dicklesworthstone/beads_rust) via `br` for issue tracking. The workspace is initialized in `.beads/`.

Typical commands:

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

Important:

- `br` does not run git commands for you.
- Track issue state by syncing with `br sync --flush-only` and staging `.beads/` explicitly.
- Treat `docs/index.md` as the canonical map for the rest of the docs set.
