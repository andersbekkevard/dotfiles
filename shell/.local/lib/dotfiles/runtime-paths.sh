# Shared runtime path contract for setup and login shells.

dotfiles_default_pnpm_home() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf '%s\n' "$HOME/Library/pnpm" ;;
    *) printf '%s\n' "$HOME/.local/share/pnpm" ;;
  esac
}
