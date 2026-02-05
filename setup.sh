#!/bin/bash
#
# Ubuntu Development Environment Setup
# ========================================
# Idempotent setup script - safe to run multiple times.
# Uses apt for system packages and Linuxbrew for CLI tools.
#
# Usage:
#   git clone -b ubuntu https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./setup.sh
#   exec zsh
#

set -euo pipefail

# =============================================================================
# CONSTANTS AND HELPERS
# =============================================================================

readonly DOTFILES_DIR="$HOME/.dotfiles"
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Check if command exists
has() { command -v "$1" &>/dev/null; }

# Run command with sudo if not root
as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Retry apt commands (handles lock files from auto-updates)
apt_install() {
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if as_root apt-get install -y "$@"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            warn "apt is locked or failed. Waiting 5 seconds before retry ($attempt/$max_attempts)..."
            sleep 5
        fi
        ((attempt++))
    done

    error "Failed to install packages after $max_attempts attempts"
}

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

cd "$DOTFILES_DIR" 2>/dev/null || error "Clone dotfiles to ~/.dotfiles first"

[[ "$OSTYPE" == linux-gnu* ]] || error "This branch is for Ubuntu/Linux only"

# Check if running as root
IS_ROOT=false
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    warn "Running as root - will use apt instead of Homebrew for CLI tools"
fi

log "Detected Linux (Ubuntu branch)"

# =============================================================================
# SYSTEM PACKAGES (apt)
# =============================================================================

export DEBIAN_FRONTEND=noninteractive

log "Updating package lists..."
as_root apt-get update -qq || error "Failed to update apt. Check your internet connection."

log "Installing base system packages..."
apt_install build-essential curl git procps file locales zsh stow

log "Installing i3 desktop environment..."
apt_install i3 polybar rofi picom feh maim xclip xdotool xcape alacritty kitty

log "Installing CLI tools via apt..."
apt_install neovim fzf ripgrep fd-find bat htop btop jq zoxide wget ffmpeg p7zip-full tmux

# These may not be in all repos - try individually
as_root apt-get install -y lsd 2>&1 || warn "lsd not available in apt"
as_root apt-get install -y lazygit 2>&1 || warn "lazygit not available in apt"
as_root apt-get install -y gh 2>&1 || warn "gh not available in apt"
as_root apt-get install -y yazi 2>&1 || warn "yazi not available in apt"

# Ubuntu renames some tools - create standard symlinks
[[ -f /usr/bin/batcat ]] && as_root ln -sf /usr/bin/batcat /usr/local/bin/bat
[[ -f /usr/bin/fdfind ]] && as_root ln -sf /usr/bin/fdfind /usr/local/bin/fd

log "System packages installed."

# Locale configuration
if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    log "Configuring locale..."
    as_root locale-gen en_US.UTF-8 || warn "Failed to generate locale"
fi
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# =============================================================================
# SNAP PACKAGES
# =============================================================================

if has snap; then
    log "Installing snap packages..."
    as_root snap install ghostty --classic 2>&1 || warn "ghostty snap not available"
fi

# =============================================================================
# HOMEBREW (Linuxbrew) + CLI TOOLS (non-root only)
# =============================================================================

if [[ "$IS_ROOT" == "false" ]]; then
    # Add Linuxbrew to PATH if already installed
    if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    if ! has brew; then
        log "Installing Linuxbrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Homebrew installation failed"
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        log "Linuxbrew installed."
    fi

    log "Installing CLI tools via Homebrew..."

    BREW_PACKAGES=(
        zsh stow git curl wget jq fzf ripgrep fd bat
        htop btop zoxide lsd lazygit neovim gh ffmpeg p7zip poppler
        go yazi
    )

    brew install "${BREW_PACKAGES[@]}" || warn "Some Homebrew packages failed"
    log "Homebrew packages installed."
fi

# =============================================================================
# FONTS (MesloLGS Nerd Font for Powerlevel10k)
# =============================================================================

FONT_DIR="$HOME/.local/share/fonts"
if [[ ! -f "$FONT_DIR/Meslo LG S Regular Nerd Font Complete.ttf" ]]; then
    log "Installing MesloLGS Nerd Font..."
    mkdir -p "$FONT_DIR"

    MESLO_BASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    if curl -fsSL "$MESLO_BASE/Meslo.tar.xz" -o /tmp/meslo-nerd-font.tar.xz; then
        tar -xf /tmp/meslo-nerd-font.tar.xz -C "$FONT_DIR"
        rm -f /tmp/meslo-nerd-font.tar.xz
        fc-cache -f "$FONT_DIR"
        log "MesloLGS Nerd Font installed."
    else
        warn "Failed to download MesloLGS Nerd Font"
    fi
fi

# =============================================================================
# GREENCLIP (clipboard manager for rofi)
# =============================================================================

if [[ ! -f "$HOME/.local/bin/greenclip" ]]; then
    log "Installing greenclip..."
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL "https://github.com/erebe/greenclip/releases/download/v4.2/greenclip" -o "$HOME/.local/bin/greenclip"; then
        chmod +x "$HOME/.local/bin/greenclip"
        log "greenclip installed."
    else
        warn "Failed to download greenclip"
    fi
fi

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    log "Installing NVM..."
    if curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
        log "NVM installed."
    else
        warn "NVM installation failed"
    fi
fi
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# Node.js
if ! has node; then
    log "Installing Node.js LTS..."
    if nvm install --lts && nvm use --lts && nvm alias default node; then
        log "Node.js installed."
    else
        warn "Node.js installation failed"
    fi
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
if ! has pnpm; then
    log "Installing pnpm..."
    if curl -fsSL https://get.pnpm.io/install.sh | sh -; then
        log "pnpm installed."
    else
        warn "pnpm installation failed"
    fi
fi

# Global npm packages
log "Installing global npm packages..."
npm install -g @google/gemini-cli 2>/dev/null || warn "gemini-cli install failed"

# uv (Python package manager)
if ! has uv; then
    log "Installing uv..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log "uv installed."
    else
        warn "uv installation failed"
    fi
fi

# Go (via Homebrew or system)
if ! has go && [[ "$IS_ROOT" == "true" ]]; then
    log "Installing Go..."
    apt_install golang-go || warn "Go installation failed"
fi

# Claude CLI
if ! has claude; then
    log "Installing Claude CLI..."
    if curl -fsSL https://storage.googleapis.com/anthropic-sdk/claude-code/claude-code-latest-linux-x64.tar.gz | tar xz -C "$HOME/.local/bin" 2>/dev/null; then
        log "Claude CLI installed."
    else
        npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "Claude CLI installation failed"
    fi
fi

# =============================================================================
# ZSH + OH MY ZSH + PLUGINS
# =============================================================================

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    if RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        log "Oh My Zsh installed."
    else
        warn "Oh My Zsh installation failed - continuing anyway"
    fi
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

ZSH_PLUGINS=(
    "powerlevel10k|themes/powerlevel10k|https://github.com/romkatv/powerlevel10k.git"
    "zsh-autosuggestions|plugins/zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|plugins/zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

for plugin_spec in "${ZSH_PLUGINS[@]}"; do
    IFS='|' read -r name path url <<< "$plugin_spec"
    target="$ZSH_CUSTOM/$path"
    if [[ ! -d "$target" ]]; then
        log "Installing $name..."
        mkdir -p "$(dirname "$target")"
        if GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$target"; then
            log "$name installed."
        else
            warn "Failed to install $name"
        fi
    fi
done

# =============================================================================
# DOTFILES: STOW
# =============================================================================

log "Stowing dotfiles..."
cd "$DOTFILES_DIR"

# Remove any existing files/symlinks that would conflict with stow
STOW_TARGETS=(
    ~/.zshrc ~/.zshenv ~/.zprofile ~/.profile
    ~/.gitconfig ~/.p10k.zsh
    ~/.config/nvim ~/.config/fd ~/.config/rofi ~/.scripts
    ~/.config/i3 ~/.config/polybar ~/.config/alacritty
    ~/.config/kitty ~/.config/ghostty ~/.config/lazygit
    ~/.config/btop ~/.config/greenclip.toml ~/.config/fish
    ~/.config/wt ~/.config/git
    ~/.local/share/rofi/themes
    ~/.wt
)

for target in "${STOW_TARGETS[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
    fi
done

mkdir -p ~/.config ~/.scripts ~/.local/share/rofi

if stow --restow --target="$HOME" --no-folding .; then
    log "Dotfiles stowed."
else
    error "Stow failed."
fi

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell..."
    if [[ "$IS_ROOT" == "true" ]]; then
        chsh -s "$(which zsh)" || warn "Could not change shell"
    else
        sudo chsh -s "$(which zsh)" "$(whoami)" || chsh -s "$(which zsh)" || warn "Could not change shell"
    fi
fi

if [[ ! -f ~/.zshrc.local ]]; then
    log "Creating local shell config..."
    cat > ~/.zshrc.local << 'EOF'
# Machine-specific configuration (not tracked in dotfiles)

stty erase '^?' 2>/dev/null || true

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

# =============================================================================
# VERIFICATION
# =============================================================================

log "Verifying installation..."

declare -a CHECKS=(zsh node pnpm uv git stow nvim fzf bat btop lazygit gh i3 rofi polybar)

missing=()
for cmd in "${CHECKS[@]}"; do
    has "$cmd" || missing+=("$cmd")
done

[[ -L ~/.zshrc ]] || missing+=(".zshrc symlink")
[[ -L ~/.config/nvim/init.lua ]] || missing+=("nvim config symlink")
[[ -L ~/.config/i3/config ]] || missing+=("i3 config symlink")
[[ -L ~/.config/polybar/config.ini ]] || missing+=("polybar config symlink")
[[ -L ~/.wt/wt.sh ]] || missing+=("wt-cli symlink")

if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing components: ${missing[*]}"
else
    log "All components verified!"
fi

# =============================================================================
# DONE
# =============================================================================

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: exec zsh"
echo "  2. Powerlevel10k will auto-configure on first launch"
echo "  3. Log out and back into i3 for desktop changes"
echo ""
