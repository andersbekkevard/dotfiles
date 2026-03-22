export DOTFILES_PROFILE_SOURCED=1

path_prepend() {
  [ -n "$1" ] || return 0
  case ":$PATH:" in
    *:"$1":*) ;;
    *)
      if [ -n "${PATH:-}" ]; then
        PATH="$1:$PATH"
      else
        PATH="$1"
      fi
      ;;
  esac
}

path_append() {
  [ -n "$1" ] || return 0
  case ":$PATH:" in
    *:"$1":*) ;;
    *)
      if [ -n "${PATH:-}" ]; then
        PATH="$PATH:$1"
      else
        PATH="$1"
      fi
      ;;
  esac
}

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

FNM_DIR="${FNM_DIR:-$HOME/.local/share/fnm}"
export FNM_DIR
if [ -x "$FNM_DIR/fnm" ]; then
  path_prepend "$FNM_DIR"
  eval "$("$FNM_DIR/fnm" env --shell bash 2>/dev/null)"
fi

case "$(uname -s 2>/dev/null)" in
  Darwin)
    PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
    if [ -x /usr/libexec/java_home ]; then
      JAVA_HOME="$("/usr/libexec/java_home" 2>/dev/null || printf '')"
      if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME/bin" ]; then
        path_prepend "$JAVA_HOME/bin"
      fi
      [ -n "$JAVA_HOME" ] && export JAVA_HOME
    fi
    [ -d "$HOME/.antigravity/antigravity/bin" ] && path_append "$HOME/.antigravity/antigravity/bin"
    ;;
  *)
    PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    ;;
esac
export PNPM_HOME
[ -d "$PNPM_HOME" ] && path_prepend "$PNPM_HOME"

BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export BUN_INSTALL
[ -d "$BUN_INSTALL/bin" ] && path_append "$BUN_INSTALL/bin"

[ -d "$HOME/.config/emacs/bin" ] && path_prepend "$HOME/.config/emacs/bin"
[ -d "$HOME/.scripts" ] && path_append "$HOME/.scripts"
[ -d "$HOME/go/bin" ] && path_append "$HOME/go/bin"

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ] && [ -z "${HOMEBREW_PREFIX:-}" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -f "$HOME/.profile.local" ] && . "$HOME/.profile.local"
