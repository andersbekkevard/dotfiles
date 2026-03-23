#!/usr/bin/env bash

run_minimal_layer() {
  log_info "Layer: minimal"

  if [[ "$OS_FAMILY" == "darwin" ]]; then
    ensure_homebrew
    brew_bundle "$DOTFILES_DIR/setup/packages/Brewfile.minimal"
  elif [[ "$OS_FAMILY" == "linux" ]]; then
    ensure_ngrok_apt_repo
    apt_update_once
    apt_install_manifest "$DOTFILES_DIR/setup/packages/apt.minimal.txt"
    install_git_delta_linux
    install_linux_release_binaries "$DOTFILES_DIR/setup/packages/linux-binaries.minimal.txt"
    ensure_linux_command_aliases
    ensure_neovim_011
  fi

  ensure_oh_my_zsh
  ensure_zsh_plugins
  stow_packages shell git nvim tmux scripts fd btop
  ensure_tpm
  write_local_overrides_template "${ACTIVE_PROFILE:-minimal}"
  ensure_default_shell_zsh
}
