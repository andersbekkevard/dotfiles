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

## Usage

### Stowing
To apply configurations to your home directory:
```bash
cd ~/.dotfiles
stow .
```

### Backing up
To create a new snapshot of external configs:
```bash
./backups/snapshot.sh
```

Raycast isnt backed up automatically, and must be done manually
