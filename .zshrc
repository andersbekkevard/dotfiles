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

mcd() {
  mkdir -p "$1" && cd "$1"
}



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
         --bind "enter:execute(cursor "{}")+abort"
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

alias nodesize='bash ~/.scripts/nodesize.sh'

# Fuzzy finder for zsh history - puts selection in command line for editing
fh() {
  local cmd=$(fc -l 1 | fzf --tac --no-sort --exact --height=40% --reverse | sed 's/^ *[0-9]*[ *]*//; s/[[:space:]]*$//')
  if [[ -n $cmd ]]; then
    print -z "$cmd"
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
    local found=()
    local activate_script=""
    
    # Common venv directory patterns (priority order)
    local patterns=(".venv" "venv" ".env" "env" "*venv*" "*env*" "virtualenv")
    
    # First, try common patterns in current directory
    for pattern in "${patterns[@]}"; do
        for dir in $pattern(N/); do
            if [[ -f "$dir/bin/activate" ]]; then
                found+=("$dir/bin/activate")
            fi
        done
        # Stop if we found matches for this pattern
        [[ ${#found[@]} -gt 0 ]] && break
    done
    
    # Fallback: search recursively for any bin/activate (max depth 3)
    if [[ ${#found[@]} -eq 0 ]]; then
        while IFS= read -r script; do
            found+=("$script")
        done < <(find . -maxdepth 4 -path "*/bin/activate" -type f 2>/dev/null | head -5)
    fi
    
    # Handle results
    if [[ ${#found[@]} -eq 0 ]]; then
        echo "✗ No virtual environment found"
        return 1
    elif [[ ${#found[@]} -eq 1 ]]; then
        activate_script="${found[1]}"
    else
        # Multiple venvs found - let user choose
        echo "Multiple venvs found:"
        local i=1
        for script in "${found[@]}"; do
            local venv_name=$(dirname $(dirname "$script"))
            echo "  $i) $venv_name"
            ((i++))
        done
        echo -n "Select [1-${#found[@]}]: "
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#found[@]} )); then
            activate_script="${found[$choice]}"
        else
            echo "✗ Invalid selection"
            return 1
        fi
    fi
    
    # Activate the venv
    source "$activate_script"
    local venv_name=$(basename $(dirname $(dirname "$activate_script")))
    echo "✓ Activated: $venv_name"
}

# yazi wrapper to cd
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Open directory in Warp terminal
warp() {
  local target_path="${1:-.}"
  
  # Resolve to absolute path
  if [[ "$target_path" == "." ]]; then
    target_path="$PWD"
  elif [[ "$target_path" == ".."* ]]; then
    target_path="$(cd "$target_path" 2>/dev/null && pwd)"
  elif [[ "$target_path" != /* ]]; then
    target_path="$PWD/$target_path"
  fi
  
  # Verify path exists
  if [[ ! -d "$target_path" ]]; then
    echo "Error: Directory does not exist: $target_path"
    return 1
  fi
  
  # Open in Warp
  open -a "Warp" "$target_path"
}

# Function to run pytex and pdflatex
pytex() {
  if [[ -z "$1" ]]; then
    echo "usage: pytex <file[.tex]>"
    return 1
  fi
  local tex="${1%.tex}.tex"
  local dir="${tex:h}"
  local file="${tex:t}"
  local base="${file:r}"

  (
    cd "$dir" || exit 1
    # First pass: do not stop on missing graphics
    pdflatex -shell-escape -interaction=nonstopmode "$file" &&
    pythontex "$file" &&
    # Final pass: stop on real errors
    pdflatex -halt-on-error "$file"
  ) || return $?

  (
    cd "$dir" || exit 1
    rm -f "$base".{aux,log,pytxcode} 2>/dev/null
    rm -rf "pythontex-files-$base"
  )
}



## Fix common UTF-8 mis-encodings for Norwegian characters in files/directories
# Usage:
#   æøå <file|dir> [more files/dirs]
# This replaces sequences like 'Ã¥' -> 'å', 'Ã¸' -> 'ø', 'Ã¦' -> 'æ' in-place.
fix_aeoa() {
  if [[ $# -lt 1 ]]; then
    echo "usage: æøå <file|dir> [more]"
    return 1
  fi

  local target tmp file
  local processed=0 changed=0

  for target in "$@"; do
    if [[ -f "$target" ]]; then
      tmp="$(mktemp -t fix-aeoa.XXXXXX)" || return 1
      awk '{gsub(/Ã¥/, "å"); gsub(/Ã¸/, "ø"); gsub(/Ã¦/, "æ"); print}' "$target" > "$tmp" || { rm -f "$tmp"; return 1; }
      if cmp -s "$target" "$tmp"; then
        rm -f "$tmp"
      else
        mv "$tmp" "$target"
        ((changed++))
      fi
      ((processed++))
    elif [[ -d "$target" ]]; then
      while IFS= read -r -d '' file; do
        tmp="$(mktemp -t fix-aeoa.XXXXXX)" || exit 1
        awk '{gsub(/Ã¥/, "å"); gsub(/Ã¸/, "ø"); gsub(/Ã¦/, "æ"); print}' "$file" > "$tmp" || { rm -f "$tmp"; exit 1; }
        if cmp -s "$file" "$tmp"; then
          rm -f "$tmp"
        else
          mv "$tmp" "$file"
          ((changed++))
        fi
        ((processed++))
      done < <(find "$target" -type f -print0)
    else
      echo "skip: '$target' not found"
    fi
  done

  echo "✓ æøå: processed ${processed} file(s), changed ${changed}."
}

# Friendly alias with Norwegian name
alias 'æøå'=fix_aeoa

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
# export OPENROUTER_API_KEY="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"

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