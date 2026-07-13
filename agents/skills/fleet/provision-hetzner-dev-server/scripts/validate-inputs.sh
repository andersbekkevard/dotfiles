#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s root@<ip> <hostname> [username]\n' "${0##*/}" >&2
  exit 64
}

[[ $# -ge 2 && $# -le 3 ]] || usage

target="$1"
hostname="$2"
username="${3:-anders}"

[[ "$target" == root@* && "${target#root@}" != "$target" && -n "${target#root@}" ]] || {
  printf 'target must be root@<ip>: %s\n' "$target" >&2
  exit 65
}

host_part="${target#root@}"
if [[ "$host_part" == *:* ]]; then
  [[ "$host_part" =~ ^\[?[0-9a-fA-F:]+\]?$ ]] || {
    printf 'target must contain an IPv4 or IPv6 address: %s\n' "$target" >&2
    exit 65
  }
else
  [[ "$host_part" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
    printf 'target must contain an IPv4 or IPv6 address: %s\n' "$target" >&2
    exit 65
  }
  IFS=. read -r -a octets <<<"$host_part"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || {
      printf 'target contains an invalid IPv4 octet: %s\n' "$target" >&2
      exit 65
    }
  done
fi

[[ ${#hostname} -le 63 && "$hostname" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || {
  printf 'hostname must be a lowercase DNS label of at most 63 characters: %s\n' "$hostname" >&2
  exit 66
}

[[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || {
  printf 'invalid Linux username: %s\n' "$username" >&2
  exit 67
}

printf 'TARGET=%s\nHOSTNAME=%s\nUSERNAME=%s\n' "$target" "$hostname" "$username"
