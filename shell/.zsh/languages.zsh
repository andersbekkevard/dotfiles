export UV_PYTHON_PREFERENCE='managed'
export UV_PYTHON='3.13'

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

export FNM_DIR="$HOME/.local/share/fnm"
[[ ":$PATH:" != *":$FNM_DIR:"* ]] && export PATH="$FNM_DIR:$PATH"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

export BUN_INSTALL="$HOME/.bun"
[[ ":$PATH:" != *":$BUN_INSTALL/bin:"* ]] && export PATH="$PATH:$BUN_INSTALL/bin"
[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

[[ ":$PATH:" != *":$HOME/go/bin:"* ]] && export PATH="$PATH:$HOME/go/bin"

if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
[[ ":$PATH:" != *":$PNPM_HOME:"* ]] && export PATH="$PATH:$PNPM_HOME"

[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
