export EDITOR='nvim'
export OLLAMA_API_BASE='http://127.0.0.1:11434'

export PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$HOME/.config/emacs/bin:"* ]] && export PATH="$HOME/.config/emacs/bin:$PATH"
[[ ":$PATH:" != *":$HOME/.scripts:"* ]] && export PATH="$PATH:$HOME/.scripts"

if [[ -d "$HOME/.scripts/functions" ]]; then
  fpath=("$HOME/.scripts/functions" $fpath)
fi
