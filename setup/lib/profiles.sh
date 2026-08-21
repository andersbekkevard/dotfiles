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

# Profiles compose additively: each wider profile emits the narrower profile's
# list plus its own extras, so a package or command is declared exactly once.
profile_packages() {
  case "$1" in
    minimal)
      printf '%s\n' shell git nvim tmux scripts fd btop
      ;;
    full)
      profile_packages minimal
      printf '%s\n' lazygit wt lsd
      ;;
    macos)
      profile_packages full
      printf '%s\n' terminals macos
      ;;
    linux-desktop)
      profile_packages full
      printf '%s\n' terminals linux-desktop
      ;;
  esac
}

profile_commands() {
  case "$1" in
    minimal)
      printf '%s\n' git zsh stow tmux fzf rg fd bat zoxide nvim htop btop jq ngrok cloudflared delta sesh gum trufflehog fleet control-europa-desktop forward-to-me forward-from-me git-clone-subdir git-credential-gh-safe git-loc
      ;;
    full)
      profile_commands minimal
      printf '%s\n' claude claudex claudex-proxy cli-proxy-api tree-sitter fnm node pnpm codex uv cargo rustc bun lazygit lazydocker gh yazi git-crypt psql typescript-language-server
      ;;
    macos)
      profile_commands full
      printf '%s\n' brew
      ;;
    linux-desktop)
      profile_commands full
      printf '%s\n' i3 rofi polybar alacritty kitty dex feh greenclip i3lock killall maim nm-applet pactl picom setxkbmap xclip xdotool xinput xrandr xss-lock xcape
      ;;
  esac
}
