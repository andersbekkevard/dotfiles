# =================================== Terminal theme ================================== #
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme conditionally based on terminal type and shell context
if [[ -o interactive ]]; then
  # Check if we're in Neovim terminal
  if [[ -n "$NVIM" ]] || [[ -n "$VIM" ]]; then
    # Disable Powerlevel10k for Neovim terminals only
    ZSH_THEME=""
    # Set a simple prompt for Neovim
    PROMPT='%~%# '
    RPROMPT=''
  else
    # Enable Powerlevel10k for regular interactive shells (including Cursor/VSCode)
    ZSH_THEME="powerlevel10k/powerlevel10k"
  fi
else
  # Non-interactive shell - disable Powerlevel10k
  ZSH_THEME=""
  PROMPT='%~%# '
  RPROMPT=''
fi

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Source Powerlevel10k config only if theme is enabled
if [[ "$ZSH_THEME" == "powerlevel10k/powerlevel10k" ]]; then
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# ================================= Terminal setup ================================ #
# Add Homebrew completions to fpath (must be before compinit)
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH
fi

autoload -Uz compinit
compinit

# ================================= Environment ================================ #
export EDITOR='cursor'

# User local binaries
export PATH="$HOME/.local/bin:$PATH"

# Perl local setup
eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"

# ================================= Languages ================================ #
# Activate Python environment
# source ~/.globalpy/bin/activate
export UV_PYTHON_PREFERENCE=managed
export UV_PYTHON=3.13

# Export Java Home
export JAVA_HOME=$(/usr/libexec/java_home)
export PATH="$JAVA_HOME/bin:$PATH"

# Rust / Cargo
. "$HOME/.cargo/env"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "/Users/andersbekkevard/.bun/_bun" ] && source "/Users/andersbekkevard/.bun/_bun"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ================================= Scripts ================================== #
# Source all zsh scripts from .scripts folder
for config_file in ~/.scripts/*.zsh; do source "$config_file"; done

alias nodesize='bash ~/.scripts/nodesize.sh' # Is this needed?
alias pysize='bash ~/.scripts/pysize.sh' # Is this needed?

# ================================= API-keys ================================= #
[ -f ~/.secrets ] && source ~/.secrets
alias secrets="cursor ~/.secrets"

# Claude Code Router / Antigravity / Other Exports
export OLLAMA_API_BASE=http://127.0.0.1:11434
export PATH="/Users/andersbekkevard/.antigravity/antigravity/bin:$PATH"

# ================================= CLI-tools ================================ #
# zoxide (smarter cd)
eval "$(zoxide init --cmd cd zsh)"

# thefuck
eval "$(thefuck --alias fuck)"
alias tf="fuck"

# Kiro
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# .local/bin/env? (Keeping as it was in original)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# ================================= Aliases ================================ #
# General
alias zrc="cursor ~/.dotfiles/.zshrc"
alias src="source ~/.zshrc"
alias c="clear"
alias vim="nvim"
alias vi="nvim"
alias nv="nvim"
alias ..="cd .."
alias c.="cursor ."

# lsd
alias ls='lsd --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'
alias l='ls -l'
alias la='lsd -A'
alias lla='lsd -lA'
alias lt='lsd --tree --ignore-glob "__pycache__" --ignore-glob "venv" --ignore-glob "node_modules"'

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

# other
alias nrd='npm run dev'
alias nrt='npm run test'
alias nrb='npm run build'
alias nrl='npm run lint'
alias prd='pnpm dev'
alias cat='bat'
alias ghc='gh copilot'
alias fzfc="fzf --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%"
alias llm="ollama run gemma3n:latest"
alias aider-run="aider --model ollama_chat/gpt-oss:20b ."
alias cr="cargo run"
alias c-a="cursor-agent"
alias lc="rm -f *.aux *.log *.pytxcode && rm -rf pythontex-files-*/"

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
# Use Emacs key‑bindings
bindkey -v

# Undo/redo on Meta‑Z and Meta‑Y
bindkey '^[z' undo     # Alt+z triggers undo
bindkey '^[y' redo     # Alt+y triggers redo

# ================================= Enhancements ================================ #
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

export ZSH_AI_PROVIDER="openai"

# PAI (Personal AI Infrastructure) Configuration
# Added by pai-setup on 2025-12-24
export PAI_DIR="/Users/andersbekkevard/.claude"
export DA="Hal"
export DA_COLOR="red"
export ENGINEER_NAME="Anders Bekkevard"
# End PAI Configuration


# Zsh-ai Configuration
source $(brew --prefix)/share/zsh-ai/zsh-ai.plugin.zsh
ZSH_HIGHLIGHT_STYLES[comment]='fg=white,bold'
# ZSH_HIGHLIGHT_STYLES[comment]='fg=#af87ff,bold'
# export ZSH_AI_MODEL="openai/gpt-5-mini"
export ZSH_AI_MODEL="openai/gpt-5.2"
# alias 52="export ZSH_AI_MODEL='openai/gpt-5.2'"
export ZSH_AI_PROMPT_EXTEND="RECOMMENDED TOOL PREFERENCES:
- Use 'rg' (ripgrep) instead of 'grep' for all text searches.
- Use 'fd' instead of 'find' for finding files and directories.
- Use 'bat' instead of 'cat' for reading files.
- Use 'lsd' instead of 'ls' for listing files."


# School
alias sql="sqlite3"