profile_layers() {
  case "$1" in
    minimal)
      printf '%s\n' minimal
      ;;
    full)
      printf '%s\n' minimal full
      ;;
    macos)
      printf '%s\n' minimal full macos
      ;;
    linux-desktop)
      printf '%s\n' minimal full linux-desktop
      ;;
  esac
}

profile_packages() {
  local profile="$1"

  case "$profile" in
    minimal)
      printf '%s\n' shell git nvim tmux scripts fd btop
      ;;
    full)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt lsd
      ;;
    macos)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt lsd terminals macos
      ;;
    linux-desktop)
      printf '%s\n' shell git nvim tmux scripts fd btop lazygit wt lsd terminals linux-desktop
      ;;
  esac
}

profile_commands() {
  case "$1" in
    minimal)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq ngrok delta sesh gum
      ;;
    full)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq ngrok delta sesh gum tree-sitter fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt typescript-language-server
      ;;
    macos)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq ngrok delta sesh gum tree-sitter fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt brew typescript-language-server
      ;;
    linux-desktop)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq ngrok delta sesh gum tree-sitter fnm node pnpm uv cargo rustc bun lazygit gh yazi git-crypt typescript-language-server i3 rofi polybar alacritty dex feh greenclip i3lock killall maim nm-applet pactl picom setxkbmap xclip xdotool xinput xrandr xss-lock xcape
      ;;
  esac
}
