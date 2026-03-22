export EDITOR='nvim'
export OLLAMA_API_BASE='http://127.0.0.1:11434'

if [[ -d "$HOME/.scripts/functions" ]]; then
  fpath=("$HOME/.scripts/functions" $fpath)
fi
