# Dotfiles

## Structure

```
.dotfiles/
├── .config/           # Stowable config directories
│   ├── fd/
│   ├── karabiner/
│   ├── linearmouse/
│   └── nvim/
├── .oh-my-zsh/custom/ # Stowable oh-my-zsh customizations
├── .scripts/          # Stowable custom scripts
├── .zshrc, etc.       # Stowable shell configs
├── .gitconfig         # Stowable git config
│
└── backups/           # Non-stowable backups (not symlinked)
    ├── snapshot.sh    # Run this to create timestamped snapshots
    ├── sources/       # Initial backup (can be deleted after first snapshot)
    └── YYYY-MM-DD_HH-MM-SS/  # Timestamped snapshots
```

## Usage

### Stow (symlink dotfiles)
```bash
cd ~/.dotfiles
stow .
```

### Create backup snapshot
```bash
~/.dotfiles/backups/snapshot.sh
```
This creates a timestamped folder with fresh copies of:
- Cursor settings, keybindings, extensions
- VS Code settings, keybindings, extensions
- Ghostty config
- Brewfile (Homebrew packages)
- Package lists (npm, pip, cargo)
- GitHub CLI hosts

## Initial Setup on New Machine

1. Clone the repo
2. Run `stow .` to symlink dotfiles
3. Restore from latest backup snapshot:
   - `brew bundle --file=backups/LATEST/Brewfile`
   - `cat backups/LATEST/cursor/extensions.txt | xargs -L 1 cursor --install-extension`
   - `cat backups/LATEST/vscode/extensions.txt | xargs -L 1 code --install-extension`
   - Manually copy Ghostty config to `~/Library/Application Support/com.mitchellh.ghostty/config`
