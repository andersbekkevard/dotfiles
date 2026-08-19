if command -v sesh >/dev/null 2>&1; then
  eval "$(sesh completion zsh)"
fi

[[ -f "$HOME/.wt/wt.sh" ]] && source "$HOME/.wt/wt.sh"
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"
