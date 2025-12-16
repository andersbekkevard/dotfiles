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
autoload -Uz compinit
compinit

# ================================= Aliases ================================ #


# General
alias zrc="cursor ~/.zshrc"
alias src="source ~/.zshrc"
alias c="clear"
alias vim="nvim"
alias nv="nvim"
alias ..="cd .."
alias c.="cursor ."

# # lsd
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


# other
alias nrd='npm run dev'
alias nrt='npm run test'
alias nrb='npm run build'
alias nrl='npm run lint'
alias cat='bat'
alias ghc='gh copilot'
alias lg="lazygit"
alias fzfc="fzf --preview 'bat --style=numbers --color=always {}' --preview-window=right:60%"
alias llm="ollama run gemma3n:latest"
alias aider-run="aider --model ollama_chat/gpt-oss:20b ."
alias cr="cargo run"
alias c-a="cursor-agent"
alias lc="rm -f *.aux *.log *.pytxcode && rm -rf pythontex-files-*/"

# ================================= Scripts ================================== #
# Source all zsh scripts from .scripts folder
for config_file in ~/.scripts/*.zsh; do source "$config_file"; done

alias nodesize='bash ~/.scripts/nodesize.sh'

export EDITOR='cursor'

# ================================= Languages ================================ #
# Activate Python environment
source ~/.globalpy/bin/activate

# Export Java Home
export JAVA_HOME=$(/usr/libexec/java_home)
export PATH="$JAVA_HOME/bin:$PATH"
. "$HOME/.cargo/env"

# ================================= API-keys ================================= #
[ -f ~/.secrets ] && source ~/.secrets
alias secrets="cursor ~/.secrets"


# ================================= CLI-tools ================================ #
# Let zoxide use cd
eval "$(zoxide init --cmd cd zsh)"

# bun completions
[ -s "/Users/andersbekkevard/.bun/_bun" ] && source "/Users/andersbekkevard/.bun/_bun"

# export bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# thefuck
eval "$(thefuck --alias fuck)"
alias tf="fuck"

# Use Emacs key‑bindings
bindkey -e

# Undo/redo on Meta‑Z and Meta‑Y
bindkey '^[z' undo     # Alt+z triggers undo
bindkey '^[y' redo     # Alt+y triggers redo
. "$HOME/.local/bin/env"
# ================================= Enhancements ================================ #
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"


# For Claude Code Router
# export ANTHROPIC_BASE_URL="http://127.0.0.1:3456"
# export ANTHROPIC_API_KEY="anything-nonempty"
# export OPENROUTER_API_KEY="(...) check .secrets"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Ollama API endpoint for aider
export OLLAMA_API_BASE=http://127.0.0.1:11434


# ================================= History ================================ #
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS


export PATH="$HOME/.local/bin:$PATH"
export PERL5LIB=$HOME/.perl5/lib/perl5:$PERL5LIB
export PATH=$HOME/.perl5/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity
export PATH="/Users/andersbekkevard/.antigravity/antigravity/bin:$PATH"

eval "$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)"
