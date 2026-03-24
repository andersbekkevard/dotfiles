export UV_PYTHON_PREFERENCE='managed'
export UV_PYTHON='3.13'

export FNM_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"
if [[ -x "$FNM_DIR/fnm" ]]; then
  eval "$("$FNM_DIR/fnm" env --shell zsh)"
fi

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"

if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
else
  export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
fi
