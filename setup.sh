#!/bin/bash
#
# One-Stop Development Environment Setup
# Clone dotfiles, run this script, done. No manual steps.
#
# Usage:
#   git clone https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./setup.sh
#   exec zsh
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

DOTFILES_DIR="$HOME/.dotfiles"

# Ensure we're in dotfiles directory
cd "$DOTFILES_DIR" 2>/dev/null || error "Clone dotfiles to ~/.dotfiles first"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    log "Detected macOS - skipping Linux package installation"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    log "Detected Linux"
else
    error "Unsupported OS: $OSTYPE"
fi

# =============================================================================
# LINUX PACKAGE INSTALLATION
# =============================================================================
if [[ "$OS" == "linux" ]]; then
    log "Updating system packages..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq

    log "Installing core packages..."
    sudo apt-get install -y \
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
        software-properties-common

    # Fix locale
    sudo locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    # Symlinks for Ubuntu's renamed tools
    log "Creating tool symlinks..."
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    # lsd
    if ! command -v lsd &>/dev/null; then
        log "Installing lsd..."
        LSD_VERSION=$(curl -s "https://api.github.com/repos/lsd-rs/lsd/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*' | head -1)
        wget -q "https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd_${LSD_VERSION}_amd64.deb" -O /tmp/lsd.deb
        sudo dpkg -i /tmp/lsd.deb >/dev/null 2>&1
        rm -f /tmp/lsd.deb
    fi

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        log "Installing zoxide..."
        curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash >/dev/null 2>&1
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # thefuck
    if ! command -v thefuck &>/dev/null; then
        log "Installing thefuck..."
        pip3 install thefuck --user --break-system-packages -q 2>/dev/null || pip3 install thefuck --user -q 2>/dev/null || true
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        log "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*' | head -1)
        curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" 2>/dev/null
        tar xf /tmp/lazygit.tar.gz -C /tmp lazygit 2>/dev/null
        sudo install /tmp/lazygit /usr/local/bin 2>/dev/null
        rm -f /tmp/lazygit /tmp/lazygit.tar.gz
    fi

    # Neovim (use PPA for latest stable)
    if ! command -v nvim &>/dev/null; then
        log "Installing Neovim..."
        sudo add-apt-repository -y ppa:neovim-ppa/unstable
        sudo apt-get update -qq
        sudo apt-get install -y neovim
    fi

    # GitHub CLI
    if ! command -v gh &>/dev/null; then
        log "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq gh 2>/dev/null
    fi
fi

# =============================================================================
# CROSS-PLATFORM: Node.js, pnpm, uv
# =============================================================================

# NVM
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    log "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh 2>/dev/null | bash >/dev/null 2>&1
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Node.js
if ! command -v node &>/dev/null; then
    log "Installing Node.js LTS..."
    nvm install --lts >/dev/null 2>&1
    nvm use --lts >/dev/null 2>&1
    nvm alias default node >/dev/null 2>&1
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
if ! command -v pnpm &>/dev/null; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh 2>/dev/null | sh - >/dev/null 2>&1
fi

# uv
if ! command -v uv &>/dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh 2>/dev/null | sh >/dev/null 2>&1
fi

# =============================================================================
# ZSH + OH MY ZSH + THEME + PLUGINS
# =============================================================================

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Symlink Oh My Zsh custom directory from dotfiles (same setup as Mac)
# This ensures all plugins (including kimi-cli) are available
if [[ -d "$DOTFILES_DIR/.oh-my-zsh/custom" ]]; then
    log "Linking Oh My Zsh custom directory from dotfiles..."
    rm -rf "$HOME/.oh-my-zsh/custom"
    ln -sf "$DOTFILES_DIR/.oh-my-zsh/custom" "$HOME/.oh-my-zsh/custom"
    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
fi

# Powerlevel10k (install to dotfiles custom dir so it's shared)
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    log "Installing Powerlevel10k..."
    mkdir -p "$ZSH_CUSTOM/themes"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" >/dev/null 2>&1
fi

# zsh-autosuggestions (install if not already in dotfiles)
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    log "Installing zsh-autosuggestions..."
    mkdir -p "$ZSH_CUSTOM/plugins"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null 2>&1
fi

# zsh-syntax-highlighting (install if not already in dotfiles)
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    log "Installing zsh-syntax-highlighting..."
    mkdir -p "$ZSH_CUSTOM/plugins"
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null 2>&1
fi

# =============================================================================
# DOTFILES LINKING
# =============================================================================
log "Setting up dotfiles..."

cd "$DOTFILES_DIR"

# Step 1: Remove conflicting files
log "Removing conflicting files..."
rm -f ~/.zshrc ~/.zshrc.mac ~/.zshenv ~/.zprofile ~/.profile ~/.gitconfig ~/.p10k.zsh ~/.wakatime.cfg 2>/dev/null || true
rm -rf ~/.config/nvim ~/.config/fd ~/.scripts 2>/dev/null || true

# Step 2: Ensure ~/.config exists
mkdir -p ~/.config

# Step 3: Link all dotfiles
log "Creating symlinks..."

ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/.zshrc.mac" ~/.zshrc.mac
ln -sf "$DOTFILES_DIR/.gitconfig" ~/.gitconfig
ln -sf "$DOTFILES_DIR/.p10k.zsh" ~/.p10k.zsh
[[ -f "$DOTFILES_DIR/.zshenv" ]] && ln -sf "$DOTFILES_DIR/.zshenv" ~/.zshenv
ln -sf "$DOTFILES_DIR/.config/nvim" ~/.config/nvim
[[ -d "$DOTFILES_DIR/.scripts" ]] && ln -sf "$DOTFILES_DIR/.scripts" ~/.scripts

# Verify
log "Verifying symlinks..."
ls -la ~/.zshrc ~/.config/nvim 2>/dev/null || warn "Some symlinks missing"

# =============================================================================
# FINAL SHELL CONFIGURATION
# =============================================================================

# Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell..."
    sudo chsh -s "$(which zsh)" "$(whoami)" 2>/dev/null || chsh -s "$(which zsh)" 2>/dev/null || true
fi

# Create local overrides file with terminal fixes
log "Applying terminal fixes..."
cat > ~/.zshrc.local << 'EOF'
# Terminal fixes (auto-generated by setup.sh)
stty erase '^?' 2>/dev/null || true
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$HOME/.local/bin:$PATH"
EOF

# Ensure .zshrc sources the local file
if ! grep -q "zshrc.local" ~/.zshrc 2>/dev/null; then
    echo '[ -f ~/.zshrc.local ] && source ~/.zshrc.local' >> ~/.zshrc
fi

# =============================================================================
# VERIFICATION
# =============================================================================
log "Verifying installation..."

MISSING=""
command -v zsh >/dev/null || MISSING="$MISSING zsh"
command -v nvim >/dev/null || MISSING="$MISSING nvim"
command -v node >/dev/null || MISSING="$MISSING node"
command -v pnpm >/dev/null || MISSING="$MISSING pnpm"
command -v git >/dev/null || MISSING="$MISSING git"
command -v lsd >/dev/null || MISSING="$MISSING lsd"
[[ -L ~/.zshrc ]] || MISSING="$MISSING .zshrc-link"
[[ -L ~/.config/nvim ]] || MISSING="$MISSING nvim-config-link"

if [[ -n "$MISSING" ]]; then
    warn "Some components may need attention:$MISSING"
else
    log "All components verified!"
fi

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Run this now:"
echo ""
echo "  exec zsh"
echo ""
echo "Then Powerlevel10k will auto-configure on first launch."
echo ""
