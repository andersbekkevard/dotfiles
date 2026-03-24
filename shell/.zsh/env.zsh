export EDITOR='nvim'

if [[ -d "$HOME/.scripts/functions" ]]; then
  fpath=("$HOME/.scripts/functions" $fpath)
fi
