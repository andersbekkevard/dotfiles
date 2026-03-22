# Migration

The repository started as diverged `main` and `ubuntu` branches. Phase 1 created a clean worktree and semantically synced the live Ubuntu intent into a `main`-based branch. Phase 2 completed the structural migration:

- replaced the flat repo with explicit stow packages
- replaced the old branch-specific bootstrap with a layered single-entry `setup.sh`
- split the shell into `core`, `env`, `aliases`, `languages`, `tools`, and `mac`
- removed dead tracked files such as `.nvimlog`, `lazy-lock.json`, fish `uv.env.fish`, and the old `backups/` snapshots
- restored useful macOS-specific configuration into the `macos/` package
