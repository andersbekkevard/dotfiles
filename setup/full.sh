#!/usr/bin/env bash

run_full_layer() {
  log_info "Layer: full"

  if [[ "$OS_FAMILY" == "darwin" ]]; then
    ensure_homebrew
    brew_bundle "$DOTFILES_DIR/setup/packages/Brewfile.full"
  fi

  install_shared_runtimes
  if [[ "$OS_FAMILY" == "linux" ]]; then
    install_go_linux
  fi

  stow_packages lazygit wt
}
