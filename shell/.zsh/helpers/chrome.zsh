chrome-unlock() {
  local cipher="$HOME/.chrome-encrypted"
  local mount="$HOME/.config/google-chrome"

  if mountpoint -q "$mount" 2>/dev/null; then
    echo "✓ Already unlocked"; return 0
  fi

  # If mount dir has leftover files (Chrome ran without the encrypted mount),
  # stash them so gocryptfs can mount cleanly
  if [[ -d "$mount" ]] && [[ -n "$(ls -A "$mount" 2>/dev/null)" ]]; then
    local stash="$HOME/.chrome-stale-$(date +%s)"
    echo "⚠ Mount point not empty — stashing stale profile to $stash"
    mv "$mount" "$stash"
  fi

  mkdir -p "$mount"

  if ! gocryptfs "$cipher" "$mount"; then
    echo "✗ Failed to unlock Chrome."
    return 1
  fi
  echo "✓ Chrome unlocked. Start Chrome now."
}

chrome-lock() {
  local mount="$HOME/.config/google-chrome"

  if pgrep -f chrome > /dev/null 2>&1; then
    echo "✗ Close Chrome first!"; return 1
  fi

  # Case 1: encrypted mount is active — unmount it
  if mountpoint -q "$mount" 2>/dev/null; then
    if ! fusermount3 -u "$mount"; then
      echo "✗ Failed to unmount."; return 1
    fi
    echo "✓ Chrome locked."
    return 0
  fi

  # Case 2: no mount, but Chrome left stale unencrypted data — stash it
  if [[ -d "$mount" ]] && [[ -n "$(ls -A "$mount" 2>/dev/null)" ]]; then
    local stash="$HOME/.chrome-stale-$(date +%s)"
    echo "⚠ No encrypted mount was active — Chrome was running unprotected."
    echo "⚠ Stashing stale profile to $stash"
    mv "$mount" "$stash"
    mkdir -p "$mount"
    echo "✓ Stale profile removed. Data was NOT encrypted this session."
    return 0
  fi

  echo "✓ Nothing to lock."
}
