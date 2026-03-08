[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

FNM_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"
if [ -d "$FNM_DIR" ]; then
  case ":$PATH:" in
    *:"$FNM_DIR":*) ;;
    *) PATH="$FNM_DIR:$PATH" ;;
  esac
  export FNM_DIR PATH

  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --shell bash 2>/dev/null)"
  fi
fi

if [ "${OSTYPE#darwin}" != "$OSTYPE" ]; then
  PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
else
  PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
fi
case ":$PATH:" in
  *:"$PNPM_HOME":*) ;;
  *) PATH="$PNPM_HOME:$PATH" ;;
esac
export PNPM_HOME PATH

BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
if [ -d "$BUN_INSTALL/bin" ]; then
  case ":$PATH:" in
    *:"$BUN_INSTALL/bin":*) ;;
    *) PATH="$BUN_INSTALL/bin:$PATH" ;;
  esac
fi
export BUN_INSTALL PATH

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
