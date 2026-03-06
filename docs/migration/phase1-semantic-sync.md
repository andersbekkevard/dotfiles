# Phase 1 Semantic Sync (2026-03-06)

## Scope completed in this phase

- Created clean implementation branch/worktree at `feat/dotfiles-prd-v1-5-sync` from `main` using `wt`.
- Merged `origin/ubuntu` into it with conflict-aware resolution and no changes to `/home/anders/.dotfiles`.
- Applied live working-tree intent from `/home/anders/.dotfiles` as intent-only updates (`.tmux.conf`, `.zshrc`) and copied untracked docs intent (`docs/design-principles.md`).
- Completed removal of obsolete `backups/` history and macOS/ubuntu branch-drift artifacts by honoring the merge outcome from `ubuntu` plus main conflict choices.

## What was synchronized

### Added from `ubuntu`
- Linux desktop stack and window-manager tooling configs (`i3`, `polybar`, `rofi`, `alacritty`, `kitty`, `ghostty`, `greenclip`).
- Linux desktop package and runtime wiring (`.config/git/ignore`, `setup.sh`, `.wt/wt.sh`, `btop`, `fish`, `terminal` and status tooling).
- New helper scripts and runtime helpers (`.scripts/chrome.zsh`, `server-mode.sh`, `toggle-gui.zsh`, terminal/theme artifacts).

### Preserved from `main`
- Explicit local conflict-safe shell behavior where it did not contradict Ubuntu behavior.
- Main-only cleanups to portability and hard-coded-path-safe behavior where aligned with Ubuntu intent.

### Live working-tree intent applied
- `.tmux.conf` updated to match `/home/anders/.dotfiles` intent:
  - use unquoted `bind-key -n C-l send-keys C-l`
  - keep `christoomey/vim-tmux-navigator` off.
- `.zshrc` updated to match current intent:
  - `alias co="codex --yolo"`
  - switch OpenClaw completion sourcing from a hardcoded `/home/anders/...` path to `$HOME/...`

### Cleanups represented in merged state
- `.nvimlog` removals.
- `backups/` cleanup/removal across timestamped snapshot directories.
- legacy macOS-only tracked files removed from the synced branch (`.zshrc.mac`, Karabiner, LinearMouse artifacts).

## What remains for full PRD implementation
- Single-repo architecture changes still pending:
  - package-layered init/bootstrap (`init.sh`) and layer flags (`--layer`, `--verify`, `--stow`).
  - explicit profile chain implementation and headless/desktop/macos profile separation.
  - `.git-crypt` enablement and secret handling flow.
  - split stow package strategy with explicit `docs` as non-stowed.
  - explicit platform guards and machine-specific local overrides consolidation.

## Risk areas for parity (macOS vs ThinkPad)
- `main`/`ubuntu` behavior still reflects current branch split history in some files (`.zshrc` still sources machine/workstation helper paths and runtime details).
- `macOS`-specific config currently depends on optional helper installation behavior (`brew --prefix` checks, zsh-ai sourcing).
- Function/tool runtime version sources differ by OS and may need normalization when `init.sh` layers are introduced in phase 2.
- Desktop-only package sets are currently Ubuntu-specific and not yet modeled as explicit profile gating in phase 1.
