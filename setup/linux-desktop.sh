#!/usr/bin/env bash

run_linux_desktop_layer() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    return 0
  fi

  log_info "Layer: linux-desktop"
  apt_install_manifest "$DOTFILES_DIR/setup/packages/apt.desktop.txt"
  install_meslo_font_linux
  install_greenclip
  install_ghostty_snap
  install_agent_browser
  stow_packages terminals linux-desktop
}
