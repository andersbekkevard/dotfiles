#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'usage: %s <ssh-target> [timeout-seconds]\n' "${0##*/}" >&2
  exit 64
fi

target="$1"
timeout="${2:-900}"
ssh_bin="${SSH_BIN:-ssh}"
[[ "$timeout" =~ ^[0-9]+$ && "$timeout" -gt 0 ]] || exit 65

deadline=$((SECONDS + timeout))
attempt=0
while (( SECONDS < deadline )); do
  attempt=$((attempt + 1))
  if "$ssh_bin" -o BatchMode=yes -o ConnectTimeout=5 "$target" true 2>/dev/null; then
    printf 'SSH_READY target=%s attempts=%s elapsed=%ss\n' \
      "$target" "$attempt" "$((timeout - (deadline - SECONDS)))"
    exit 0
  fi
  sleep 10
done

printf 'SSH_TIMEOUT target=%s timeout=%ss\n' "$target" "$timeout" >&2
exit 1
