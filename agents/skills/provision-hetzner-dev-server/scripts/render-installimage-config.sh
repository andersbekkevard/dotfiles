#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  printf 'usage: %s <hostname> <drive1> <drive2> <output>\n' "${0##*/}" >&2
  exit 64
fi

hostname="$1"
drive1="$2"
drive2="$3"
output="$4"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-inputs.sh" root@127.0.0.1 "$hostname" >/dev/null

for drive in "$drive1" "$drive2"; do
  [[ "$drive" =~ ^/dev/[a-zA-Z0-9._/-]+$ ]] || {
    printf 'invalid drive path: %s\n' "$drive" >&2
    exit 65
  }
done
[[ "$drive1" != "$drive2" ]] || {
  printf 'drive paths must be distinct\n' >&2
  exit 66
}

image="${HETZNER_IMAGE:-/root/images/Ubuntu-2404-noble-amd64-base.tar.zst}"
mkdir -p "$(dirname "$output")"
tmp="$(mktemp "${output}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
umask 077

printf '%s\n' \
  "DRIVE1 $drive1" \
  "DRIVE2 $drive2" \
  'SWRAID 1' \
  'SWRAIDLEVEL 1' \
  "HOSTNAME $hostname" \
  'BOOTLOADER grub' \
  'PART swap swap 16384' \
  'PART /boot ext4 1024' \
  'PART btrfs.1 btrfs all' \
  'SUBVOL btrfs.1 @ /' \
  'SUBVOL btrfs.1 @home /home' \
  'SUBVOL btrfs.1 @docker /var/lib/docker' \
  'SUBVOL btrfs.1 @snapshots /snapshots' \
  "IMAGE $image" >"$tmp"

mv "$tmp" "$output"
trap - EXIT

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$output"
else
  shasum -a 256 "$output"
fi
