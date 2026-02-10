# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A personal dotfiles repository managed with **GNU Stow**. The repo root mirrors `$HOME` — stow creates symlinks from `~` pointing into this repo. Once linked, edits here are live immediately.

## Key Commands

```bash
# Symlink all dotfiles to $HOME (dry run first)
cd ~/.dotfiles && stow -nv .    # preview
cd ~/.dotfiles && stow -v .     # apply

# Full setup on a new machine
cd ~/.dotfiles && ./setup.sh          # Linux/macOS
cd ~/.dotfiles && ./setup.sh --with-rust  # include Rust toolchain + yazi/dust/tokei

# Snapshot non-stowable configs (VSCode, Brew, Ghostty, etc.)
./backups/snapshot.sh
```

You only need to re-run `stow` when adding **new files** to the repo. Editing existing files requires no re-stow.

## Architecture

### Stow Symlink System
- Root files (`.zshrc`, `.gitconfig`, `.p10k.zsh`, etc.) → symlinked to `~/`
- `.config/nvim/` → symlinked to `~/.config/nvim/`
- `.scripts/` → symlinked to `~/.scripts/`
- `.stow-local-ignore` excludes repo metadata, `backups/`, `.oh-my-zsh/`, mac-only app configs (karabiner, linearmouse), and editor settings (`.cursor/`, `.claude/`) from stowing

### Zsh Configuration
- `.zshrc` — main config, portable across macOS and Linux
- `.zshrc.mac` — sourced first on macOS only (Homebrew FPATH, Bun, Go, pnpm mac paths, Cursor aliases)
- `.zshrc.local` — machine-specific overrides, not tracked (created by `setup.sh`)
- `.scripts/*.zsh` — all files auto-sourced by `.zshrc`; organized by concern (fuzzy.zsh, venv.zsh, navigation.zsh, etc.)
- `.secrets` — API keys, gitignored, sourced at shell startup
- Uses **Oh My Zsh** with powerlevel10k theme, zsh-autosuggestions, zsh-syntax-highlighting
- Vi mode enabled (`bindkey -v`)
- `zoxide` replaces `cd` (aliased via `--cmd cd`)

### Neovim Configuration
- Entry: `init.lua` → `require("anders")` → loads set, keybinds, autocmds, lazy_init
- Plugin management via **lazy.nvim** with environment-aware loading
- `lua/anders/lazy/init.lua` checks `vim.g.vscode`:
  - **VS Code/Cursor**: loads only `shared/` + `vscode/` plugins (flash.nvim, highlight)
  - **Full Neovim**: loads `shared/` + `full/` plugins (LSP, telescope, completion, oil, theme, lazygit)
- To add a plugin: create a file in the appropriate subdirectory (`full/`, `shared/`, or `vscode/`)
- Leader key: Space
- The `.md` files in the nvim config root (`jon.md`, `vetle.md`, `prime.md`) are example/reference files, not actual configuration

### Backups
- `backups/snapshot.sh` captures non-stowable configs (Cursor/VSCode settings, Homebrew Brewfile, global npm/pip packages, Ghostty config) into timestamped directories
- `manifest.json` documents original locations of all managed files

## Important Conventions

- **Never use `--adopt` for daily stow operations** — it overwrites repo files with local versions; only for initial setup
- macOS-specific code should go in `.zshrc.mac`, not `.zshrc`
- New shell utilities go in `.scripts/` as separate `.zsh` files (auto-sourced)
- CLI tool preferences: `rg` over `grep`, `fd` over `find`, `bat` over `cat`, `lsd` over `ls`
