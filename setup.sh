#!/bin/bash
#
# Development Environment Setup for Linux
# ========================================
# Idempotent setup script - safe to run multiple times.
#
# Usage:
#   git clone https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
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

# Install from GitHub release (for tools not in apt)
install_github_release() {
    local name=$1 repo=$2 pattern=$3 extract_cmd=$4

    if has "$name"; then
        return 0
    fi

    log "Installing $name..."
    local version
    version=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*' | head -1)
    local url="https://github.com/$repo/releases/download/v${version}/${pattern/VERSION/$version}"

    curl -fsSL "$url" -o "/tmp/$name.archive"
    eval "$extract_cmd"
    rm -f "/tmp/$name.archive"
}

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================

cd "$DOTFILES_DIR" 2>/dev/null || error "Clone dotfiles to ~/.dotfiles first"

# Detect OS
case "$OSTYPE" in
    darwin*)
        OS="mac"
        log "Detected macOS - skipping Linux package installation"
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
    sudo apt-get update -qq

    log "Installing system packages..."
    sudo apt-get install -y -qq \
        git \
        zsh \
        curl \
        wget \
        unzip \
        stow \
        fzf \
        ripgrep \
        fd-find \
        bat \
        htop \
        jq \
        python3 \
        python3-pip \
        python3-venv \
        locales \
        software-properties-common \
        2>/dev/null

    # Locale configuration
    if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
        log "Configuring locale..."
        sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    fi
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    # Ubuntu renames some tools - create standard symlinks
    log "Creating tool aliases..."
    [[ -f /usr/bin/batcat ]] && sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
    [[ -f /usr/bin/fdfind ]] && sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd

    # Tools from GitHub releases (not in apt or outdated)
    install_github_release "lsd" "lsd-rs/lsd" "lsd_VERSION_amd64.deb" \
        "sudo dpkg -i /tmp/lsd.archive >/dev/null 2>&1"

    install_github_release "lazygit" "jesseduffield/lazygit" "lazygit_VERSION_Linux_x86_64.tar.gz" \
        "tar xzf /tmp/lazygit.archive -C /tmp lazygit && sudo install /tmp/lazygit /usr/local/bin && rm -f /tmp/lazygit"

    # zoxide (has its own installer)
    if ! has zoxide; then
        log "Installing zoxide..."
        curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash >/dev/null 2>&1
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Neovim (PPA for latest)
    if ! has nvim; then
        log "Installing Neovim..."
        sudo add-apt-repository -y ppa:neovim-ppa/unstable >/dev/null 2>&1
        sudo apt-get update -qq
        sudo apt-get install -y -qq neovim 2>/dev/null
    fi

    # GitHub CLI
    if ! has gh; then
        log "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
            sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
            sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq gh 2>/dev/null
    fi
fi

# =============================================================================
# CROSS-PLATFORM: DEVELOPMENT TOOLS
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

# =============================================================================
# ZSH + OH MY ZSH + PLUGINS
# =============================================================================

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    if ! RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1; then
        warn "Oh My Zsh installation failed - continuing anyway"
    fi
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# External plugins and themes (cloned to ~/.oh-my-zsh/custom, not tracked in dotfiles)
# Format: "name|path|url" (bash 3.x compatible - no associative arrays)
ZSH_PLUGINS=(
    "powerlevel10k|themes/powerlevel10k|https://github.com/romkatv/powerlevel10k.git"
    "zsh-autosuggestions|plugins/zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
    "zsh-syntax-highlighting|plugins/zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
    "kimi-cli|plugins/kimi-cli|https://github.com/wodify/zsh-kimi-cli.git"
)

for plugin_spec in "${ZSH_PLUGINS[@]}"; do
    IFS='|' read -r name path url <<< "$plugin_spec"
    target="$ZSH_CUSTOM/$path"
    if [[ ! -d "$target" ]]; then
        log "Installing $name..."
        mkdir -p "$(dirname "$target")"
        if ! git clone --depth=1 "$url" "$target" >/dev/null 2>&1; then
            warn "Failed to install $name - continuing anyway"
        fi
    fi
done

# =============================================================================
# DOTFILES: STOW
# =============================================================================

# Ensure stow is available
if ! has stow; then
    error "stow is not installed. On Linux, run: sudo apt-get install stow"
fi

log "Stowing dotfiles..."
cd "$DOTFILES_DIR"

# Remove any existing files that would conflict with stow
# (stow won't overwrite existing files, only create new symlinks)
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
    # Only remove if it's a regular file/directory (not already a symlink)
    if [[ -e "$target" && ! -L "$target" ]]; then
        rm -rf "$target"
    fi
done

# Ensure parent directories exist
mkdir -p ~/.config

# Stow everything (uses .stow-local-ignore to exclude non-dotfiles)
# --restow: re-stow (unlink then link) for idempotency
# --no-folding: create directories instead of symlinking them
if ! stow --restow --target="$HOME" --no-folding . 2>/tmp/stow-error.log; then
    error "Stow failed. Check /tmp/stow-error.log for details"
fi

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

# Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$(whoami)" 2>/dev/null || \
        chsh -s "$(which zsh)" 2>/dev/null || \
        warn "Could not change shell - run: chsh -s \$(which zsh)"
fi

# Create machine-local overrides (not tracked in git)
if [[ ! -f ~/.zshrc.local ]]; then
    log "Creating local shell config..."
    cat > ~/.zshrc.local << 'EOF'
# Machine-specific configuration (not tracked in dotfiles)
# Add local customizations here

# Terminal fixes
stty erase '^?' 2>/dev/null || true

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Local PATH additions
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

# =============================================================================
# VERIFICATION
# =============================================================================

log "Verifying installation..."

declare -a CHECKS=(
    "zsh"
    "nvim"
    "node"
    "pnpm"
    "git"
    "stow"
)

missing=()
for cmd in "${CHECKS[@]}"; do
    has "$cmd" || missing+=("$cmd")
done

# Check symlinks
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
