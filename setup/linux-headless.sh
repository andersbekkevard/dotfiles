#!/usr/bin/env bash

run_linux_headless_layer() {
  if [[ "$OS_FAMILY" != "linux" ]]; then
    return 0
  fi

  log_info "Layer: linux-headless"
}
