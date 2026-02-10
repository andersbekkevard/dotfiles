# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Configuration Architecture

This is a **dynamic Neovim configuration** that adapts based on the environment:

### Environment Detection
- Uses `vim.g.vscode` to detect VS Code/Cursor environment
- Loads different plugin sets based on detection in `lua/anders/lazy/init.lua`

### Directory Structure
```
lua/anders/
├── init.lua              # Main entry point
├── set.lua              # Neovim preferences and options
├── keybinds.lua         # Core keybindings (both environments + Neovim-only)
├── autocmds.lua         # Autocommands (highlight on yank)
├── lazy_init.lua        # Lazy.nvim setup
└── lazy/
    ├── init.lua         # Dynamic plugin loader
    ├── shared/          # Configs used in both environments
    │   └── flash.lua   # Flash.nvim (motion plugin)
    ├── full/           # Full Neovim only
    │   ├── telescope.lua
    │   ├── theme.lua
    │   ├── lsp.lua
    │   ├── completion.lua
    │   ├── oil.lua
    │   └── vim-be-good.lua
    └── vscode/         # VS Code/Cursor specific
        └── highlight.lua # Highlight on yank for VS Code
```

### Configuration Logic
- **VS Code/Cursor**: Minimal setup with flash.nvim, core keybinds, and highlight on yank
- **Regular Neovim**: Full feature set including LSP, telescope, themes, completion, plus additional Neovim-only keybinds
- **Shared configs**: Flash configuration is shared; keybindings are loaded in both environments with Neovim-specific additions

## Key Configurations

### Leader Key
Space is set as the leader key (`vim.g.mapleader = " "`)

### Core Keybindings (always loaded)
- `H` / `L` - Jump to line start/end (instead of `^` / `$`)
- `<leader>w` - Quick save
- `<leader>y` / `<leader>Y` - Copy to system clipboard
- `<leader>p` / `<leader>P` - Paste from system clipboard
- `<leader>m` / `<leader>M` - Replace to next/previous underscore
- `n` / `N` - Centered search navigation
- `j` / `k` - Visual line movement (soft-wrapped text)

### Environment-Specific Features
- **Flash.nvim**: Available in both environments with `s` for jump, `<leader>s` for treesitter
- **VS Code only**: Simplified keybind set, relies on VS Code for most functionality
- **Regular Neovim only**: Full LSP, telescope, themes, and completion plugins

## Development Notes

### Adding New Plugins
- **Shared between both**: Add to `lua/anders/lazy/shared/`
- **Full Neovim only**: Add to `lua/anders/lazy/full/`
- **VS Code only**: Add to `lua/anders/lazy/vscode/`

**CRITICAL**: Plugins are NOT auto-discovered. After creating a plugin file, you MUST add a `require()` statement in `lua/anders/lazy/init.lua` in the appropriate return block (vscode or full Neovim). Simply creating the file in the subdirectory is not enough.

### Shell Configuration
- Uses zsh with interactive mode (`-i -c`) for shell commands
- Colorcolumn at 80 characters (100 for Rust files)

### Plugin Management
Uses lazy.nvim with automatic installation. Plugin configs are modular and environment-aware.

## Important Context and Guidance

### Interpreting Configuration References
- `@jon.md`, `@vetle.md`, and `@prime.md` are ONLY example files
- When asked "How can I do this" or "How is x implemented", ALWAYS refer to the ACTUAL real .lua config files, NOT these markdown example files

### Tmux Integration
- Uses `christoomey/vim-tmux-navigator` plugin for seamless navigation between nvim splits and tmux panes
- Requires matching tmux plugin: `set -g @plugin 'christoomey/vim-tmux-navigator'` in `.tmux.conf`
- Navigation keybinds (`C-h/j/k/l`) are handled by the plugin, not manual keymaps
- When adding the nvim plugin: create the file in `full/`, then add `require("anders.lazy.full.vim-tmux-navigator")` to `init.lua`
