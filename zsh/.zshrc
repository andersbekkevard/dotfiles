# =================================== Terminal theme ================================== #
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme conditionally based on terminal type
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
  ZSH_THEME=""  # Disable Powerlevel10k inside Cursor
else
  ZSH_THEME="powerlevel10k/powerlevel10k"
fi

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Configure prompt based on terminal
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
# export VIRTUAL_ENV_DISABLE_PROMPT=1
# %n@%m:
  PROMPT='%~%# '
  RPROMPT=''
else
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
alias ..="cd .."

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
alias gp='git push'
alias gpl='git pull'
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


# Custom fuzzy finder function (not exact)
ff() {
  fd --type f --follow \
    --exclude "*.photoslibrary" \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    --exclude '*.log' \
    --exclude .DS_Store \
    --exclude .venv \
    --exclude OfficeFileCache \
  . | fzf --preview 'bat --style=numbers --color=always --line-range :100 {}' \
         --bind "enter:execute(code "{}")+abort"
}

# (exact match only)
ffe() {
  fd --type f --follow \
    --exclude "*.photoslibrary" \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    --exclude '*.log' \
    --exclude .DS_Store \
    --exclude .venv \
    --exclude OfficeFileCache \
  . | fzf --exact --preview 'bat --style=numbers --color=always --line-range :100 {}' \
         --bind "enter:execute(code "{}")+abort"
}

alias claude="/Users/andersbekkevard/.claude/local/claude"
alias nodesize='bash ~/.scripts/nodesize.sh'

# Custom fuzzy finder for zsh history
fh() {
  local cmd=$(fc -l 1 | fzf --tac --no-sort --exact | sed 's/^ *[0-9]* *//')
  if [[ -n $cmd ]]; then
    echo "$cmd"
    eval "$cmd"
  fi
}

# Custom fuzzy finder for directories
fdir() {
  local dir
  dir=$(fd --type d . \
    --exclude .git \
    --exclude node_modules \
    --exclude __pycache__ \
    --exclude .venv \
    --exclude target \
  | fzf --preview 'lsd --color=always --icon=always --tree --depth=6 {} | head -200' \
        --preview-window=right:65%:wrap) && cd "$dir"
}




# Script to activate nearest venv
av() {
local activate_script=$(fd -H -I -t f 'activate' | grep 'bin/activate' | head -1)
    
    if [[ -n "$activate_script" && -f "$activate_script" ]]; then
        source "$activate_script"
        echo "✓ Activated: $(basename $(dirname $(dirname $activate_script)))"
    else
        echo "✗ No virtual environment found"
        return 1
    fi
}

# yazi wrapper to cd
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

export EDITOR='cursor'

# ================================= Languages ================================ #
# Activate Python environment
source ~/.globalpy/bin/activate

# Export Java Home
export JAVA_HOME=$(/usr/libexec/java_home)
export PATH="$JAVA_HOME/bin:$PATH"

# ================================= API-keys ================================= #
[ -f ~/.zsh_secrets ] && source ~/.zsh_secrets
alias secrets="cursor ~/.zsh_secrets"


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

# # Fix broken movement keys after compinit
# bindkey "^[[1;2D" backward-char       # ⇧←
# bindkey "^[[1;2C" forward-char        # ⇧→
# bindkey "^[[1;5D" backward-word       # ⌥←
# bindkey "^[[1;5C" forward-word        # ⌥→
# bindkey "^[[1;9D" beginning-of-line   # ⌘←
# bindkey "^[[1;9C" end-of-line         # ⌘→

# ================================= Enhancements ================================ #
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh