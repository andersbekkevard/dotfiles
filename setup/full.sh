#!/usr/bin/env bash

run_full_layer() {
  log_info "Layer: full"

  if [[ "$OS_FAMILY" == "darwin" ]]; then
    ensure_homebrew
    brew_bundle "$DOTFILES_DIR/setup/packages/Brewfile.full"
  elif [[ "$OS_FAMILY" == "linux" ]]; then
    ensure_gh_apt_repo
    apt_update_once
    apt_install_manifest "$DOTFILES_DIR/setup/packages/apt.full.txt"
    install_linux_release_binaries
  fi

  install_shared_runtimes
  if [[ "$OS_FAMILY" == "linux" ]]; then
    install_go_linux
  fi

  stow_packages lazygit wt
}
