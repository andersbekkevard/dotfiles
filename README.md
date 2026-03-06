# .dotfiles (Ubuntu)

My Ubuntu development environment, managed with GNU Stow. Clone and run `setup.sh` for a fully working i3 + Gruvbox dev setup.

## Quick Setup

```bash
git clone -b ubuntu https://github.com/andersbekkevard/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup.sh
exec zsh
```

Then log out and into i3 for desktop changes.

## What's Included

### Desktop Environment
- **i3** window manager with keybindings, gaps, auto-start
- **Polybar** status bar (Gruvbox Dark Hard theme)
- **Rofi** application launcher (Gruvbox Dark Hard custom theme)
- **Picom** compositor, **feh** wallpaper, **greenclip** clipboard manager
- **xcape** for Caps Lock → Super/Escape remap

### Terminals
- **Alacritty**, **Kitty**, **Ghostty** (snap)

### Shell
- **Zsh** with Oh My Zsh, **Powerlevel10k** theme
- Plugins: zsh-autosuggestions, zsh-syntax-highlighting
- Custom scripts in `.scripts/`

### CLI Tools
- **neovim**, **fzf**, **ripgrep**, **fd**, **bat**, **lsd**, **zoxide**
- **lazygit**, **btop**, **htop**, **gh**, **yazi**, **jq**, **tmux**

### Dev Tools
- **Node.js** (via nvm) + **pnpm**
- **Python** (via uv)
- **Go** (via Homebrew)
- **Claude CLI**, **Gemini CLI**

## Project Structure

```
~/.dotfiles/
├── .zshrc, .zprofile, .zshenv, .profile   # Shell configs
├── .p10k.zsh                               # Powerlevel10k theme
├── .gitconfig                              # Git config
├── .scripts/                               # Custom shell scripts
├── .wt/                                    # wt-cli (git worktree manager)
├── .config/
│   ├── nvim/          # Neovim
│   ├── i3/            # i3 window manager
│   ├── polybar/       # Status bar
│   ├── rofi/          # App launcher
│   ├── alacritty/     # Terminal
│   ├── kitty/         # Terminal
│   ├── ghostty/       # Terminal
│   ├── lazygit/       # Git TUI
│   ├── btop/          # System monitor
│   ├── fd/            # fd search
│   ├── fish/          # Fish shell
│   ├── git/           # Global gitignore
│   ├── wt/            # wt-cli config
│   └── greenclip.toml # Clipboard manager
├── .local/share/rofi/themes/               # Custom rofi themes
├── setup.sh                                # Idempotent setup script
└── manifest.json                           # File manifest
```

## Usage

### Stowing (Symlinking)

Simulate first (dry run):
```bash
cd ~/.dotfiles && stow -nv --no-folding .
```

Apply:
```bash
stow --restow --no-folding .
```

You only need to re-run stow when adding new files to the repo. Editing existing files takes effect immediately since they're symlinked.

## Theme

**Gruvbox Dark Hard** across the entire environment:
- Polybar, Rofi, Neovim (base16), terminal configs
