#!/bin/bash
#
# Dotfiles Backup Snapshot Script
# Creates a timestamped snapshot of non-stowable config files
#
# This script is STATELESS - it only READS from system locations
# and WRITES to the backups folder. It never modifies original files.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SNAPSHOT_DIR="$SCRIPT_DIR/$TIMESTAMP"

echo "Creating snapshot: $TIMESTAMP"
mkdir -p "$SNAPSHOT_DIR"

# ============ Cursor ============
echo "  Backing up Cursor..."
mkdir -p "$SNAPSHOT_DIR/cursor"
cp "$HOME/Library/Application Support/Cursor/User/settings.json" "$SNAPSHOT_DIR/cursor/" 2>/dev/null || echo "    (settings.json not found)"
cp "$HOME/Library/Application Support/Cursor/User/keybindings.json" "$SNAPSHOT_DIR/cursor/" 2>/dev/null || echo "    (keybindings.json not found)"
cursor --list-extensions > "$SNAPSHOT_DIR/cursor/extensions.txt" 2>/dev/null || echo "    (cursor CLI not available)"

# ============ VS Code ============
echo "  Backing up VS Code..."
mkdir -p "$SNAPSHOT_DIR/vscode"
cp "$HOME/Library/Application Support/Code/User/settings.json" "$SNAPSHOT_DIR/vscode/" 2>/dev/null || echo "    (settings.json not found)"
cp "$HOME/Library/Application Support/Code/User/keybindings.json" "$SNAPSHOT_DIR/vscode/" 2>/dev/null || echo "    (keybindings.json not found)"
code --list-extensions > "$SNAPSHOT_DIR/vscode/extensions.txt" 2>/dev/null || echo "    (code CLI not available)"

# ============ Ghostty ============
echo "  Backing up Ghostty..."
mkdir -p "$SNAPSHOT_DIR/ghostty"
cp "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "$SNAPSHOT_DIR/ghostty/config" 2>/dev/null || echo "    (config not found)"

# ============ Homebrew ============
echo "  Backing up Homebrew packages..."
brew bundle dump --describe --file="$SNAPSHOT_DIR/Brewfile" 2>/dev/null || echo "    (brew not available)"

# ============ Package Lists ============
echo "  Backing up package lists..."
mkdir -p "$SNAPSHOT_DIR/packages"
npm list -g --depth=0 > "$SNAPSHOT_DIR/packages/npm-global.txt" 2>/dev/null || echo "    (npm not available)"
"$HOME/.globalpy/bin/pip" freeze > "$SNAPSHOT_DIR/packages/globalpy-requirements.txt" 2>/dev/null || echo "    (.globalpy not found)"
cargo install --list > "$SNAPSHOT_DIR/packages/cargo.txt" 2>/dev/null || echo "    (cargo not available)"

# ============ Warp Themes ============
echo "  Backing up Warp themes..."
mkdir -p "$SNAPSHOT_DIR/warp-themes"
cp "$HOME/.warp/themes/anders.yml" "$SNAPSHOT_DIR/warp-themes/" 2>/dev/null || true
cp "$HOME/.warp/themes/anders-new.yml" "$SNAPSHOT_DIR/warp-themes/" 2>/dev/null || true
# Copy any other custom .yml files in the root (not in subdirs)
find "$HOME/.warp/themes" -maxdepth 1 -name "*.yml" -exec cp {} "$SNAPSHOT_DIR/warp-themes/" \; 2>/dev/null || echo "    (warp themes not found)"

# ============ GitHub CLI Auth ============
echo "  Backing up GitHub CLI hosts..."
mkdir -p "$SNAPSHOT_DIR/gh"
cp "$HOME/.config/gh/hosts.yml" "$SNAPSHOT_DIR/gh/hosts.yml" 2>/dev/null || echo "    (hosts.yml not found)"

echo ""
echo "Snapshot complete: $SNAPSHOT_DIR"
echo ""
echo "Files created:"
find "$SNAPSHOT_DIR" -type f | sed 's|'"$SNAPSHOT_DIR"'/|  |'
