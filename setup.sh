#!/bin/bash
# Minimal Linux/Mac Development Environment Setup
# For TypeScript development with great DX
#
# Installs: Node.js, pnpm, Python, uv, Neovim, CLI tools, Zsh + Powerlevel10k
# Skips: Rust, Java, Go, build tools

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}==>${NC} $1"; }

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    log "Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    log "Detected Linux"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

# ============ LINUX SETUP ============
if [[ "$OS" == "linux" ]]; then
    log "Updating package lists..."
    sudo apt update

    log "Installing core packages..."
    sudo apt install -y \
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
        python3-venv

    # Create symlinks for tools with different names on Ubuntu
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null || true
    sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

    # Install lsd (modern ls)
    if ! command -v lsd &>/dev/null; then
        log "Installing lsd..."
        LSD_VERSION=$(curl -s "https://api.github.com/repos/lsd-rs/lsd/releases/latest" | grep -Po '"tag_name": "v?\K[^"]*')
        wget -q "https://github.com/lsd-rs/lsd/releases/download/v${LSD_VERSION}/lsd_${LSD_VERSION}_amd64.deb" -O /tmp/lsd.deb
        sudo dpkg -i /tmp/lsd.deb
        rm /tmp/lsd.deb
    fi

    # Install zoxide (smart cd)
    if ! command -v zoxide &>/dev/null; then
        log "Installing zoxide..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    fi

    # Install thefuck
    if ! command -v thefuck &>/dev/null; then
        log "Installing thefuck..."
        pip3 install thefuck --user --break-system-packages 2>/dev/null || pip3 install thefuck --user
    fi

    # Install lazygit
    if ! command -v lazygit &>/dev/null; then
        log "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -sLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin
        rm /tmp/lazygit /tmp/lazygit.tar.gz
    fi

    # Install Neovim (latest)
    if ! command -v nvim &>/dev/null; then
        log "Installing Neovim..."
        curl -sLo /tmp/nvim.tar.gz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
        sudo rm -rf /opt/nvim-linux64
        sudo tar -C /opt -xzf /tmp/nvim.tar.gz
        sudo ln -sf /opt/nvim-linux64/bin/nvim /usr/local/bin/nvim
        rm /tmp/nvim.tar.gz
    fi

    # Install GitHub CLI
    if ! command -v gh &>/dev/null; then
        log "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
    fi
fi

# ============ SHARED SETUP (Linux & Mac) ============

# Install NVM + Node.js
if [[ ! -d "$HOME/.nvm" ]]; then
    log "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
    log "Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
fi

# Install pnpm
if ! command -v pnpm &>/dev/null; then
    log "Installing pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
fi

# Install uv (Python package manager)
if ! command -v uv &>/dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install Powerlevel10k
if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
    log "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

# Install zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    log "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    log "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# ============ DOTFILES SETUP ============
if [[ -d "$HOME/.dotfiles" ]]; then
    log "Setting up dotfiles..."
    cd "$HOME/.dotfiles"

    # Use Linux-specific configs if on Linux
    if [[ "$OS" == "linux" ]]; then
        [[ -f ".zshrc.linux" ]] && cp .zshrc.linux .zshrc
        [[ -f ".stow-local-ignore.linux" ]] && cp .stow-local-ignore.linux .stow-local-ignore
    fi

    # Stow dotfiles
    stow -v . 2>&1 | grep -v "BUG" || true
fi

# Change default shell to zsh
if [[ "$SHELL" != *"zsh"* ]]; then
    log "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
fi

echo ""
log "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Exit and reconnect (or run: exec zsh)"
echo "  2. Powerlevel10k will auto-configure on first run"
echo "  3. Run 'gh auth login' to authenticate GitHub"
echo ""
