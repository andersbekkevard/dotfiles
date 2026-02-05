#!/bin/bash
#
# Development Environment Setup
# ========================================
# Idempotent setup script - safe to run multiple times.
# Works as root (apt-only) or normal user (Homebrew for CLI tools).
#
# Usage:
#   git clone https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./setup.sh
#   exec zsh
#
# Options:
#   --with-rust    Install Rust and Rust-based CLI tools (slow, off by default)
#

set -euo pipefail

# =============================================================================
# FLAG PARSING
# =============================================================================

INSTALL_RUST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-rust)
            INSTALL_RUST=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./setup.sh [--with-rust]"
            exit 1
            ;;
    esac
done

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

# Check if running as root
IS_ROOT=false
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    warn "Running as root - will use apt instead of Homebrew for CLI tools"
fi

# Detect OS
case "$OSTYPE" in
    darwin*)
        OS="mac"
        log "Detected macOS"
        ;;
    linux-gnu*)
        OS="linux"
        log "Detected Linux"
        ;;
    *)
        error "Unsupported OS: $OSTYPE"
        ;;
esac

# =============================================================================
# LINUX: SYSTEM PACKAGES
# =============================================================================

if [[ "$OS" == "linux" ]]; then
    export DEBIAN_FRONTEND=noninteractive

    log "Updating package lists..."
    as_root apt-get update -qq || error "Failed to update apt. Check your internet connection."

    log "Installing base system packages..."
    apt_install build-essential curl git procps file locales zsh stow
    log "Base packages installed."

    log "Installing i3 desktop environment packages..."
    apt_install i3 polybar rofi picom feh maim xclip xdotool alacritty || true
    as_root apt-get install -y kitty 2>&1 || warn "kitty not available in apt"
    log "Desktop packages installed."

    # If running as root, install CLI tools via apt (since no Homebrew)
    if [[ "$IS_ROOT" == "true" ]]; then
        log "Installing CLI tools via apt..."
        apt_install neovim fzf ripgrep fd-find bat htop btop jq zoxide wget ffmpeg p7zip-full || true

        # These may not be in all repos - try individually
        as_root apt-get install -y lsd 2>&1 || warn "lsd not available in apt"
        as_root apt-get install -y lazygit 2>&1 || warn "lazygit not available in apt"
        as_root apt-get install -y gh 2>&1 || warn "gh not available in apt"

        # Ubuntu renames some tools - create standard symlinks
        [[ -f /usr/bin/batcat ]] && as_root ln -sf /usr/bin/batcat /usr/local/bin/bat
        [[ -f /usr/bin/fdfind ]] && as_root ln -sf /usr/bin/fdfind /usr/local/bin/fd
        log "CLI tools installed via apt."
    fi

    # Locale configuration
    if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
        log "Configuring locale..."
        as_root locale-gen en_US.UTF-8 || warn "Failed to generate locale"
    fi
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
fi

# =============================================================================
# HOMEBREW + CLI TOOLS (non-root only)
# =============================================================================

if [[ "$IS_ROOT" == "false" ]]; then
    # Add Homebrew to PATH first (if already installed)
    if [[ "$OS" == "linux" ]] && [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    if ! has brew; then
        log "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Homebrew installation failed"
        log "Homebrew installed."
        # Add newly installed Homebrew to PATH
        if [[ "$OS" == "linux" ]]; then
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        else
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    log "Installing CLI tools via Homebrew..."

    BREW_PACKAGES=(
        zsh stow git curl wget jq fzf ripgrep fd bat
        htop btop zoxide lsd lazygit neovim gh ffmpeg p7zip poppler
    )

    if [[ "$INSTALL_RUST" == "true" ]]; then
        BREW_PACKAGES+=(yazi dust tokei)
    fi

    brew install "${BREW_PACKAGES[@]}" || error "Homebrew package installation failed"
    log "Homebrew packages installed."
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

# uv (Python package manager)
if ! has uv; then
    log "Installing uv..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh; then
        log "uv installed."
    else
        warn "uv installation failed"
    fi
fi

# Rust toolchain
if [[ "$INSTALL_RUST" == "true" ]]; then
    if ! has rustup; then
        log "Installing Rust toolchain..."
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
            log "Rust installed."
        else
            warn "Rust installation failed"
        fi
    fi
else
    log "Skipping Rust (use --with-rust to enable)"
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
    ~/.zshrc ~/.zshrc.mac ~/.zshenv ~/.zprofile ~/.profile
    ~/.gitconfig ~/.p10k.zsh ~/.wakatime.cfg
    ~/.config/nvim ~/.config/fd ~/.config/rofi ~/.scripts
    ~/.config/i3 ~/.config/polybar ~/.config/alacritty
    ~/.config/kitty ~/.config/ghostty ~/.config/lazygit
    ~/.config/btop ~/.config/greenclip.toml ~/.config/fish
)

for target in "${STOW_TARGETS[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
    fi
done

mkdir -p ~/.config ~/.scripts

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

declare -a CHECKS=(zsh node pnpm uv git stow nvim fzf)

if [[ "$INSTALL_RUST" == "true" ]] && [[ "$IS_ROOT" == "false" ]]; then
    CHECKS+=("yazi" "dust" "tokei")
fi

missing=()
for cmd in "${CHECKS[@]}"; do
    has "$cmd" || missing+=("$cmd")
done

[[ -L ~/.zshrc ]] || missing+=(".zshrc symlink")
# With --no-folding, nvim dir contains symlinks (not a symlink itself)
[[ -L ~/.config/nvim/init.lua ]] || missing+=("nvim config symlink")

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
echo ""
