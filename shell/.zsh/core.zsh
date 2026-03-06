[[ -t 0 ]] && stty -ixon

export ZSH="$HOME/.oh-my-zsh"

if [[ "$OSTYPE" == darwin* ]] && command -v brew >/dev/null 2>&1; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

if [[ -o interactive ]]; then
  if [[ -n "$NVIM" ]] || [[ -n "$VIM" ]]; then
    ZSH_THEME=""
    PROMPT='%~%# '
    RPROMPT=''
  elif [[ -d "$ZSH/custom/themes/powerlevel10k" ]]; then
    ZSH_THEME="powerlevel10k/powerlevel10k"
  else
    ZSH_THEME="robbyrussell"
  fi
else
  ZSH_THEME=""
  PROMPT='%~%# '
  RPROMPT=''
fi

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

[[ -n "${ZSH_HIGHLIGHT_STYLES+x}" ]] && ZSH_HIGHLIGHT_STYLES[comment]='fg=white,bold'
[[ "$ZSH_THEME" == "powerlevel10k/powerlevel10k" && -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

autoload -Uz compinit chpwd_recent_dirs cdr add-zsh-hook
compinit
add-zsh-hook chpwd chpwd_recent_dirs

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

bindkey -v
bindkey '^[z' undo
bindkey '^[y' redo
