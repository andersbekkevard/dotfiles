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

    log "Installing system packages via apt..."
    as_root apt-get update -qq

    # Base packages (always needed)
    as_root apt-get install -y -qq \
        build-essential \
        curl \
        git \
        procps \
        file \
        locales \
        zsh \
        stow \
        2>/dev/null

    # If running as root, install CLI tools via apt (since no Homebrew)
    if [[ "$IS_ROOT" == "true" ]]; then
        log "Installing CLI tools via apt..."
        as_root apt-get install -y -qq \
            neovim \
            fzf \
            ripgrep \
            fd-find \
            bat \
            htop \
            btop \
            jq \
            zoxide \
            wget \
            ffmpeg \
            p7zip-full \
            2>/dev/null || true

        # Try to install lsd and lazygit (may not be in all repos)
        as_root apt-get install -y -qq lsd 2>/dev/null || true
        as_root apt-get install -y -qq lazygit 2>/dev/null || true
        as_root apt-get install -y -qq gh 2>/dev/null || true

        # Ubuntu renames some tools - create standard symlinks
        [[ -f /usr/bin/batcat ]] && as_root ln -sf /usr/bin/batcat /usr/local/bin/bat
        [[ -f /usr/bin/fdfind ]] && as_root ln -sf /usr/bin/fdfind /usr/local/bin/fd
    fi

    # Locale configuration
    if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
        log "Configuring locale..."
        as_root locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    fi
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
fi

# =============================================================================
# HOMEBREW + CLI TOOLS (non-root only)
# =============================================================================

if [[ "$IS_ROOT" == "false" ]]; then
    if ! has brew; then
        log "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Add Homebrew to PATH for this session
    if [[ "$OS" == "linux" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    log "Installing CLI tools via Homebrew..."

    BREW_PACKAGES=(
        zsh
        stow
        git
        curl
        wget
        jq
        fzf
        ripgrep
        fd
        bat
        htop
        btop
        zoxide
        lsd
        lazygit
        neovim
        gh
        ffmpeg
        p7zip
        poppler
    )

    if [[ "$INSTALL_RUST" == "true" ]]; then
        BREW_PACKAGES+=(yazi dust tokei)
    fi

    brew install "${BREW_PACKAGES[@]}"
fi

# =============================================================================
# DEVELOPMENT TOOLS (standalone installers, work for both root and non-root)
# =============================================================================

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    log "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >/dev/null 2>&1
fi
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# Node.js
if ! has node; then
    log "Installing Node.js LTS..."
    nvm install --lts >/dev/null 2>&1
    nvm use --lts >/dev/null 2>&1
    nvm alias default node >/dev/null 2>&1
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
if ! has pnpm; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh - >/dev/null 2>&1
fi

# uv (Python package manager)
if ! has uv; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
fi

# Rust toolchain
if [[ "$INSTALL_RUST" == "true" ]]; then
    if ! has rustup; then
        log "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
    fi
else
    log "Skipping Rust installation (use --with-rust to enable)"
fi

# =============================================================================
# ZSH + OH MY ZSH + PLUGINS
# =============================================================================

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    if ! RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1; then
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
        if ! GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$target" >/dev/null 2>&1; then
            warn "Failed to install $name - continuing anyway"
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
    ~/.zshrc
    ~/.zshrc.mac
    ~/.zshenv
    ~/.zprofile
    ~/.profile
    ~/.gitconfig
    ~/.p10k.zsh
    ~/.wakatime.cfg
    ~/.config/nvim
    ~/.config/fd
    ~/.scripts
)

for target in "${STOW_TARGETS[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target"
    fi
done

mkdir -p ~/.config

if ! stow --restow --target="$HOME" --no-folding . 2>/tmp/stow-error.log; then
    error "Stow failed. Check /tmp/stow-error.log for details"
fi

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell..."
    if [[ "$IS_ROOT" == "true" ]]; then
        chsh -s "$(which zsh)" 2>/dev/null || warn "Could not change shell"
    else
        sudo chsh -s "$(which zsh)" "$(whoami)" 2>/dev/null || \
            chsh -s "$(which zsh)" 2>/dev/null || \
            warn "Could not change shell"
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

declare -a CHECKS=(
    "zsh"
    "node"
    "pnpm"
    "uv"
    "git"
    "stow"
    "nvim"
    "fzf"
)

if [[ "$INSTALL_RUST" == "true" ]] && [[ "$IS_ROOT" == "false" ]]; then
    CHECKS+=("yazi" "dust" "tokei")
fi

missing=()
for cmd in "${CHECKS[@]}"; do
    has "$cmd" || missing+=("$cmd")
done

[[ -L ~/.zshrc ]] || missing+=(".zshrc symlink")
[[ -L ~/.config/nvim ]] || missing+=("nvim config symlink")

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
