#!/bin/bash

toggle-gui() {
  local xsession="$HOME/.xsession"
  local current

  current=$(cat "$xsession" 2>/dev/null)

  if [[ "$current" == *"i3"* ]]; then
    echo "startxfce4" > "$xsession"
    echo "Switched to XFCE"
  else
    echo "exec i3" > "$xsession"
    echo "Switched to i3"
  fi
}
