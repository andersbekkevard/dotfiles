#!/bin/bash
#
# One-Stop Development Environment Setup
# Clone dotfiles, run this script, done.
#
# Usage:
#   git clone https://github.com/USERNAME/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles && ./setup.sh
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# Must be run from ~/.dotfiles
DOTFILES_DIR="$HOME/.dotfiles"
if [[ "$(pwd)" != "$DOTFILES_DIR" ]]; then
    if [[ -d "$DOTFILES_DIR" ]]; then
        cd "$DOTFILES_DIR"
    else
        error "Run this from ~/.dotfiles"
    fi
fi

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
    sudo apt update -qq

    log "Installing core packages..."
    sudo apt install -y -qq \
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
        > /dev/null

    # Fix locale (prevents some terminal issues)
    sudo locale-gen en_US.UTF-8 > /dev/null 2>&1 || true
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    # Symlinks for Ubuntu's renamed tools
    log "Creating tool symlinks..."
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    # lsd
    if ! command -v lsd &>/dev/null; then
        log "Installing lsd..."
        LSD_VERSION=$(curl -s "https://api.github.com/repos/lsd-rs/lsd/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*')
        wget -q "https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd_${LSD_VERSION}_amd64.deb" -O /tmp/lsd.deb
        sudo dpkg -i /tmp/lsd.deb > /dev/null
        rm /tmp/lsd.deb
    fi

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        log "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash > /dev/null 2>&1
    fi

    # thefuck
    if ! command -v thefuck &>/dev/null; then
        log "Installing thefuck..."
        pip3 install thefuck --user --break-system-packages -q 2>/dev/null || pip3 install thefuck --user -q
    fi

    # lazygit
    if ! command -v lazygit &>/dev/null; then
        log "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -sLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin
        rm /tmp/lazygit /tmp/lazygit.tar.gz
    fi

    # Neovim
    if ! command -v nvim &>/dev/null; then
        log "Installing Neovim..."
        curl -sLo /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
        sudo rm -rf /opt/nvim-linux64
        sudo tar -C /opt -xzf /tmp/nvim.tar.gz
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
        rm /tmp/nvim.tar.gz
    fi

    # GitHub CLI
    if ! command -v gh &>/dev/null; then
        log "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update -qq && sudo apt install -y -qq gh > /dev/null
    fi
fi

# =============================================================================
# CROSS-PLATFORM TOOLS (Node, Python, Zsh)
# =============================================================================

# NVM + Node.js
export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    log "Installing NVM..."
    curl -so- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash > /dev/null 2>&1
fi
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
    log "Installing Node.js LTS..."
    nvm install --lts > /dev/null 2>&1
    nvm use --lts > /dev/null 2>&1
fi

# pnpm
if ! command -v pnpm &>/dev/null; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh - > /dev/null 2>&1
fi

# uv (Python)
if ! command -v uv &>/dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
fi

# =============================================================================
# ZSH + OH MY ZSH + PLUGINS
# =============================================================================

# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" > /dev/null 2>&1
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    log "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" > /dev/null 2>&1
fi

# zsh-autosuggestions
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    log "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" > /dev/null 2>&1
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    log "Installing zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" > /dev/null 2>&1
fi

# =============================================================================
# DOTFILES LINKING
# =============================================================================
log "Linking dotfiles..."

cd "$DOTFILES_DIR"

# Use Linux-specific configs
if [[ "$OS" == "linux" ]]; then
    [[ -f ".zshrc.linux" ]] && cp .zshrc.linux .zshrc
    [[ -f ".stow-local-ignore.linux" ]] && cp .stow-local-ignore.linux .stow-local-ignore
fi

# Remove ALL conflicting files that would block stow
log "Cleaning up conflicting files..."
rm -f ~/.zshrc ~/.zshenv ~/.zprofile ~/.profile ~/.gitconfig ~/.p10k.zsh 2>/dev/null || true
rm -rf ~/.config/nvim 2>/dev/null || true
rm -rf ~/.scripts 2>/dev/null || true

# Stow everything
log "Running stow..."
stow -v --restow . 2>&1 | grep -E "^(LINK|UNLINK)" || true

# Verify critical symlinks
if [[ -L ~/.zshrc ]]; then
    log "~/.zshrc linked successfully"
else
    warn "~/.zshrc not linked, forcing..."
    ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
fi

if [[ -L ~/.config/nvim || -d ~/.config/nvim ]]; then
    log "~/.config/nvim linked successfully"
else
    warn "~/.config/nvim not linked, forcing..."
    mkdir -p ~/.config
    ln -sf "$DOTFILES_DIR/.config/nvim" ~/.config/nvim
fi

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

# Change default shell to zsh
if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting zsh as default shell..."
    chsh -s "$(which zsh)" 2>/dev/null || warn "Could not change shell automatically"
fi

# Fix common terminal issues
log "Configuring terminal settings..."
cat >> ~/.zshrc.local 2>/dev/null << 'EOF' || true
# Terminal fixes
stty erase '^?' 2>/dev/null || true
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF

# Source local overrides in .zshrc if not already there
if ! grep -q "zshrc.local" ~/.zshrc 2>/dev/null; then
    echo '[ -f ~/.zshrc.local ] && source ~/.zshrc.local' >> ~/.zshrc
fi

# =============================================================================
# DONE
# =============================================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installed:"
echo "  - Node.js $(node --version 2>/dev/null || echo '(reload shell)')"
echo "  - pnpm $(pnpm --version 2>/dev/null || echo '(reload shell)')"
echo "  - Python $(python3 --version 2>/dev/null | cut -d' ' -f2)"
echo "  - Neovim $(nvim --version 2>/dev/null | head -1 | cut -d' ' -f2 || echo 'installed')"
echo "  - Zsh + Powerlevel10k + plugins"
echo "  - CLI tools: lsd, bat, rg, fd, fzf, zoxide, lazygit"
echo ""
echo "Next steps:"
echo "  1. Run: exec zsh"
echo "  2. Powerlevel10k will configure itself"
echo "  3. Optional: gh auth login"
echo ""
