if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
  alias zi='cdi'
  alias za='zoxide add'
fi

if command -v thefuck >/dev/null 2>&1 && thefuck --version >/dev/null 2>&1; then
  eval "$(thefuck --alias fuck)"
  alias tf='fuck'
fi

if command -v sesh >/dev/null 2>&1; then
  eval "$(sesh completion zsh)"
fi

[[ -f "$HOME/.wt/wt.sh" ]] && source "$HOME/.wt/wt.sh"
