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
  PROMPT='%n@%m:%~%# '
  RPROMPT=''
else
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

# ================================= Terminal setup ================================ #
autoload -Uz compinit
compinit

# ================================= Aliases ================================ #
# General
alias zrc="code ~/.zshrc"
alias src="source ~/.zshrc"
alias c="clear"
alias ..="cd .."

# lsd
alias ls='lsd'
alias l='ls -l'
alias la='ls -A'
alias lla='ls -lA'
alias lt='ls --tree'

# git
alias g='git'
alias ga='git add'
alias gb='git branch'
alias gc='git commit -m'
alias gs='git status -sb'
alias gp='git push'
alias gpl='git pull'
alias gbm='git branch -M main'

# other
alias cat='bat'
alias ghc='gh copilot'
alias lg="lazygit"


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



# ================================= Languages ================================ #
# Activate Python environment
source ~/.globalpy/bin/activate

# Export Java Home
export JAVA_HOME=$(/usr/libexec/java_home)
export PATH="$JAVA_HOME/bin:$PATH"


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
