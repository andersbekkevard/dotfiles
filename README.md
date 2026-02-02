# .dotfiles

This repository manages my local configuration files (dotfiles) using GNU Stow, providing a centralized and version-controlled system for my development environment.

## Project Structure

The repository mimics the structure of the home directory (`$HOME`).

- **Root files** (`.zshrc`, `.p10k.zsh`, `.gitconfig`): Symlinked directly to `~`.
- **.config/**: Contains configuration for apps like nvim, etc. Symlinked to `~/.config`.
- **.scripts/**: Custom Zsh scripts extracted from `.zshrc` for better organization (e.g., `fuzzy.zsh`, `venv.zsh`).
- **backups/**: Stores timestamped snapshots of non-stowable configurations (not symlinked).


## Key Components

### 1. GNU Stow & `.stow-local-ignore`
This file is critical. It tells `stow` which files to **ignore** when creating symlinks. 
- **Why it's important**: We don't want repository metadata (like `.git/`, `README.md`, `manifest.json`) or the `backups/` folder to be symlinked into the home directory.
- **Content**:
  ```gitignore
  backups
  .git
  .gitignore
  .stow-local-ignore
  README.*
  ...
  ```

### 2. Git & `.gitignore`
This file ensures **security** by preventing sensitive data from being tracked.
- **Why it's important**: It excludes files containing API keys or private tokens (`.secrets`, `.wakatime.cfg`, `gh/hosts.yml` snapshots) from version control.
- **Note**: `backups/sources/sensitive/` and `backups/*/gh/` are explicitly ignored to protect authentication tokens captured during snapshots.

### 3. Backups & `snapshot.sh`
Not all configurations are suitable for symlinking (e.g., VS Code extension lists, dynamic application state, or sensitive files).

- **`backups/snapshot.sh`**: A stateless script that:
  - **Reads** current configurations from their system locations (Cursor/VSCode settings, Homebrew packages, Ghostty config, etc.).
  - **Writes** them to a new timestamped directory inside `backups/` (e.g., `backups/2025-12-16_16-04-30/`).
- **Workflow**: Run this script periodically to capture the state of your environment without linking these files directly to the live system.

## Quick Setup

### Linux (One-Command Install)
```bash
git clone https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles && ./setup.sh
exec zsh
```

### Windows (PowerShell)
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
git clone https://github.com/USERNAME/.dotfiles.git $env:USERPROFILE\.dotfiles
cd $env:USERPROFILE\.dotfiles
.\setup.ps1
```

**Windows Notes:**
- Uses PowerShell instead of Zsh (Oh My Posh replaces Powerlevel10k)
- Most CLI tools work identically (git, nvim, fzf, ripgrep, fd, bat, lsd, etc.)
- Neovim config is fully compatible
- Some Linux-specific tools aren't available
- After setup, restart PowerShell and configure Windows Terminal to use "MesloLGM Nerd Font"

## Usage

### 1. Stowing (Symlinking)

#### Simulate (Dry Run / Visual Mode)
Before applying changes, always simulate to see exactly what `stow` will do. The `-v` (verbose) flag shows you every action.
```bash
cd ~/.dotfiles
stow -nv .
```

#### Apply Changes
Once you're happy with the simulation, run the command to create the symlinks.
```bash
stow -v .
```

#### When do I need to run this?
- **Only Once**: Once linked, changes are live immediately. You do **not** need to re-run `stow` just because you edited a file (e.g., `.zshrc`).
- **New Files**: Run it if you add a *new* file to this repo that isn't yet linked in your home folder.
- **Restoring Links**: Run it if a symlink in your home directory is accidentally deleted or overwritten.
- **New Machine**: Run it after cloning this repo to a new computer.

> [!IMPORTANT]
> **About `--adopt`**: Only use the `--adopt` flag during initial setup to pull existing local configs into the repo. **Do not use it for daily updates**, as it can overwrite your repo files with local versions.

### 2. External Backups
To create a new snapshot of external configs (VSCode, Brew, etc.):
```bash
./backups/snapshot.sh
```

Raycast isn't backed up automatically and must be done manually via the app settings.
