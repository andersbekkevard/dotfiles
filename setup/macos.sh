#!/usr/bin/env bash

run_macos_layer() {
  if [[ "$OS_FAMILY" != "darwin" ]]; then
    return 0
  fi

  log_info "Layer: macos"
  ensure_homebrew
  brew_bundle "$DOTFILES_DIR/setup/packages/Brewfile.macos"
  stow_packages terminals macos
}
