#!/usr/bin/env bash

run_linux_headless_layer() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    return 0
  fi

  log_info "Layer: linux-headless"
  ensure_gh_apt_repo
  apt_update_once
  apt_install_manifest "$DOTFILES_DIR/setup/packages/apt.full.txt"
  install_linux_release_binaries
}
