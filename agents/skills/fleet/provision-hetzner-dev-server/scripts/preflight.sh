#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s root@<ip> <state-dir>\n' "${0##*/}" >&2
  exit 64
fi

target="$1"
state_dir="$2"
ssh_bin="${SSH_BIN:-ssh}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-inputs.sh" "$target" preflight >/dev/null

mkdir -p "$state_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
report="$state_dir/preflight-$timestamp.log"

set +e
"$ssh_bin" -o BatchMode=yes -o ConnectTimeout=10 "$target" 'bash -s' <<'REMOTE' | tee "$report"
set -euo pipefail

printf 'PREFLIGHT_UTC=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'REMOTE_HOSTNAME=%s\n' "$(hostname)"

if ! grep -Rqs 'Hetzner Rescue' /etc/motd /etc/issue /root/.oldroot 2>/dev/null; then
  printf 'ERROR=remote environment is not identifiable as Hetzner Rescue\n' >&2
  exit 20
fi
printf 'RESCUE_SYSTEM=Hetzner\n'

printf 'BOOT_MODE=%s\n' "$([[ -d /sys/firmware/efi ]] && printf UEFI || printf Legacy-CSM)"
printf 'KERNEL=%s\n' "$(uname -r)"
printf 'MEMORY_KIB=%s\n' "$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
printf '%s\n' '--- NETWORK ---'
ip -brief address
printf '%s\n' '--- AUTHORIZED KEYS ---'
if [[ ! -s /root/.ssh/authorized_keys ]]; then
  printf 'ERROR=/root/.ssh/authorized_keys is absent or empty\n' >&2
  exit 21
fi
ssh-keygen -lf /root/.ssh/authorized_keys

mapfile -t disks < <(
  lsblk -dnpo NAME,TYPE | awk '$2 == "disk" {print $1}' |
    grep -Ev '^/dev/(loop|ram)' | sort
)

if [[ ${#disks[@]} -ne 2 ]]; then
  printf 'ERROR=expected exactly two whole disks; found %s\n' "${#disks[@]}" >&2
  lsblk -d -o NAME,TYPE,SIZE,MODEL,SERIAL
  exit 22
fi

printf 'DRIVE1=%s\nDRIVE2=%s\n' "${disks[0]}" "${disks[1]}"
printf '%s\n' '--- DISKS ---'
lsblk -d -o NAME,TYPE,SIZE,MODEL,SERIAL,ROTA

blank=1
for disk in "${disks[@]}"; do
  printf '%s\n' "--- $disk layout ---"
  lsblk -o NAME,TYPE,SIZE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS "$disk"
  printf '%s\n' "--- $disk signatures ---"
  signatures="$(wipefs -n "$disk" 2>/dev/null || true)"
  printf '%s\n' "$signatures"
  if lsblk -nrpo TYPE "$disk" | grep -qx part; then
    blank=0
  fi
  if [[ -n "$(printf '%s\n' "$signatures" | tail -n +2 | tr -d '[:space:]')" ]]; then
    blank=0
  fi
  printf '%s\n' "--- $disk SMART ---"
  smartctl -a "$disk" 2>&1 || true
  if command -v nvme >/dev/null 2>&1 && [[ "$disk" == /dev/nvme* ]]; then
    nvme smart-log "$disk" 2>&1 || true
  fi
done

if grep -Eq '^md[0-9]+[[:space:]]*:' /proc/mdstat; then
  printf 'ERROR=active md arrays already exist\n' >&2
  cat /proc/mdstat
  exit 23
fi

if [[ $blank -ne 1 ]]; then
  printf 'ERROR=one or more candidate disks contain partitions or signatures\n' >&2
  exit 24
fi

image=/root/images/Ubuntu-2404-noble-amd64-base.tar.zst
if [[ ! -f "$image" ]]; then
  printf 'ERROR=required image missing: %s\n' "$image" >&2
  find /root/images -maxdepth 1 -type f -printf '%p\n' 2>/dev/null || true
  exit 25
fi
printf 'IMAGE=%s\n' "$image"
printf 'DISKS_BLANK=yes\nPREFLIGHT=PASS\n'
REMOTE
status=${PIPESTATUS[0]}
set -e

printf 'REPORT=%s\n' "$report"
exit "$status"
