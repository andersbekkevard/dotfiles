# =============================================================================
# PORTABLE ZSH CONFIGURATION
# Works on both macOS and Linux
# =============================================================================

# Source Mac-specific config if on macOS (before everything else for Homebrew FPATH)
[[ "$OSTYPE" == "darwin"* ]] && [[ -f ~/.zshrc.mac ]] && source ~/.zshrc.mac

# =================================== Terminal theme ================================== #
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme conditionally based on terminal type and shell context
if [[ -o interactive ]]; then
  if [[ -n "$NVIM" ]] || [[ -n "$VIM" ]]; then
    ZSH_THEME=""
    PROMPT='%~%# '
    RPROMPT=''
  else
    if [[ -d "$ZSH/custom/themes/powerlevel10k" ]]; then
      ZSH_THEME="powerlevel10k/powerlevel10k"
    else
      ZSH_THEME="robbyrussell"
    fi
  fi
else
  ZSH_THEME=""
  PROMPT='%~%# '
  RPROMPT=''
fi

plugins=(git kimi-cli zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Syntax highlighting styles (must be after plugin loads)
ZSH_HIGHLIGHT_STYLES[comment]='fg=white,bold'

# Source Powerlevel10k config only if theme is enabled
[[ "$ZSH_THEME" == "powerlevel10k/powerlevel10k" ]] && [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ================================= Terminal setup ================================ #
autoload -Uz compinit
compinit

# ================================= Environment ================================ #
export EDITOR='nvim'
export PATH="$HOME/.local/bin:$PATH"

# ================================= Languages ================================ #
# Python (uv)
export UV_PYTHON_PREFERENCE=managed
export UV_PYTHON=3.13

# NVM (Node.js)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# pnpm (Linux location - Mac location is in .zshrc.mac)
if [[ "$OSTYPE" != "darwin"* ]]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  [[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"
fi

# ================================= Scripts ================================== #
if [[ -d "$HOME/.scripts" ]]; then
  for config_file in ~/.scripts/*.zsh; do
    [[ -f "$config_file" ]] && source "$config_file"
  done
fi

alias nodesize='bash ~/.scripts/nodesize.sh'
alias pysize='bash ~/.scripts/pysize.sh'

# ================================= API-keys ================================= #
[ -f ~/.secrets ] && source ~/.secrets
export KIMI_API_KEY="$MOONSHOT_API_KEY"
export OLLAMA_API_BASE=http://127.0.0.1:11434

# ================================= zsh-ai (macOS) ================================ #
# Load after .secrets so API keys are available
if [[ "$OSTYPE" == "darwin"* ]] && [[ -f "$(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh" ]]; then
  # Set configuration BEFORE sourcing the plugin
  export ZSH_AI_PROVIDER="openai"
  export ZSH_AI_MODEL="openai/gpt-5.2"
  export ZSH_AI_PROMPT_EXTEND="RECOMMENDED TOOL PREFERENCES:
- Use 'rg' (ripgrep) instead of 'grep' for all text searches.
- Use 'fd' instead of 'find' for finding files and directories.
- Use 'bat' instead of 'cat' for reading files.
- Use 'lsd' instead of 'ls' for listing files."
  # Now source the plugin
  source "$(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh"
fi

# ================================= CLI-tools ================================ #
# zoxide (smarter cd)
command -v zoxide &>/dev/null && eval "$(zoxide init --cmd cd zsh)"

# thefuck (only if it works - may fail on Python 3.12+)
if command -v thefuck &>/dev/null && thefuck --version &>/dev/null 2>&1; then
  eval "$(thefuck --alias fuck)"
  alias tf="fuck"
fi

# .local/bin/env
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# ================================= Aliases ================================ #
# General
alias src="source ~/.zshrc"
alias c="clear"
alias vim="nvim"
alias vi="nvim"
alias nv="nvim"
alias ..="cd .."

# zrc alias - uses $EDITOR (nvim on Linux, cursor on Mac via .zshrc.mac override)
[[ "$OSTYPE" != "darwin"* ]] && alias zrc="$EDITOR ~/.dotfiles/.zshrc"

# lsd (if installed, otherwise fallback to ls)
if command -v lsd &>/dev/null; then
  alias ls='lsd --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'
  alias l='ls -l'
  alias la='lsd -A'
  alias lla='lsd -lA'
  alias lt='lsd --tree --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'
else
  alias ls='ls --color=auto'
  alias l='ls -l'
  alias la='ls -A'
  alias lla='ls -lA'
fi

# git
alias g='git'
alias ga='git add'
alias gb='git branch'
alias gc='git commit -m'
alias gs='git status -sb'
alias gp='git pull'
alias gpo='git push'
alias gbm='git branch -M main'
alias glog='git log --oneline --graph --decorate --all'
alias lg="lazygit"

# npm/pnpm
alias nrd='npm run dev'
alias nrt='npm run test'
alias nrb='npm run build'
alias nrl='npm run lint'
alias prd='pnpm dev'

# bat (if installed)
command -v bat &>/dev/null && alias cat='bat'

# GitHub CLI
command -v gh &>/dev/null && alias ghc='gh copilot'

# fzf
command -v fzf &>/dev/null && command -v bat &>/dev/null && \
  alias fzfc="fzf --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%"

# cargo (if installed)
command -v cargo &>/dev/null && alias cr="cargo run"

# Other
alias lc="rm -f *.aux *.log *.pytxcode && rm -rf pythontex-files-*/"
alias sql="sqlite3"

# ================================= History ================================ #
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# ================================= Keybindings ================================ #
bindkey -v
bindkey '^[z' undo
bindkey '^[y' redo

# ================================= Local Overrides ================================ #
# Source machine-specific overrides (created by setup.sh on Linux)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
