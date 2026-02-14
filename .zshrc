# =============================================================================
# ZSH CONFIGURATION (Ubuntu)
# =============================================================================

# Source .zprofile for non-login shells (so Homebrew PATH is always available)
if [[ ! -o login ]]; then
  [[ -f ~/.zprofile ]] && source ~/.zprofile
fi

# =================================== Terminal theme ================================== #
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme - Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Syntax highlighting styles (must be after plugin loads)
[[ -n "${ZSH_HIGHLIGHT_STYLES+x}" ]] && ZSH_HIGHLIGHT_STYLES[comment]='fg=white,bold'

# Source Powerlevel10k config
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

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

# Go
export PATH="$HOME/go/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PNPM_HOME:$PATH"

# ================================= Scripts ================================== #
if [[ -d "$HOME/.scripts" ]]; then
  for config_file in ~/.scripts/*.zsh; do
    [[ -f "$config_file" ]] && source "$config_file"
  done
fi

alias nodesize='bash ~/.scripts/nodesize.sh'
alias pysize='bash ~/.scripts/pysize.sh'
alias server-mode='bash ~/.scripts/server-mode.sh'

# Warn if TLP thresholds aren't enforced (server-mode battery health)
if [[ -f /etc/tlp.d/01-server-mode.conf ]]; then
  local _thresh=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null)
  if [[ "$_thresh" != "80" ]]; then
    echo -e "\033[0;31m[!] TLP battery threshold not enforced (reads ${_thresh:-?}%) — run: sudo tlp start\033[0m"
  fi
  unset _thresh
fi

# ================================= API-keys ================================= #
[ -f ~/.secrets ] && source ~/.secrets
export OLLAMA_API_BASE=http://127.0.0.1:11434

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

# zrc alias
alias zrc="$EDITOR ~/.dotfiles/.zshrc"

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
alias cc="claude --dangerously-skip-permissions"

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

# Change cursor shape based on vi mode
function zle-keymap-select {
  if [[ ${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
    echo -ne '\e[1 q'  # Block cursor for normal mode
  elif [[ ${KEYMAP} == main ]] || [[ ${KEYMAP} == viins ]] || [[ ${KEYMAP} = '' ]] || [[ $1 = 'beam' ]]; then
    echo -ne '\e[5 q'  # Beam cursor for insert mode
  fi
}
zle -N zle-keymap-select

# Use beam cursor on startup
echo -ne '\e[5 q'

# Use beam cursor for each new prompt
function zle-line-init {
  echo -ne "\e[5 q"
}
zle -N zle-line-init

# ================================= Local Overrides ================================ #
# Source machine-specific overrides (created by setup.sh on Linux)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# wt-cli
source "$HOME/.wt/wt.sh"

# OpenClaw Completion
source "/home/anders/.openclaw/completions/openclaw.zsh"
alias tui="openclaw tui"
