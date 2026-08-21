#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <administrator@host> <expected-hostname>\n' "${0##*/}" >&2
  exit 64
fi

target="$1"
expected_hostname="$2"
ssh_bin="${SSH_BIN:-ssh}"
admin="${target%%@*}"
host="${target#*@}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/validate-inputs.sh" root@127.0.0.1 "$expected_hostname" "$admin" >/dev/null

"$ssh_bin" -o BatchMode=yes -o ConnectTimeout=10 "$target" \
  'bash -s' -- "$expected_hostname" <<'REMOTE'
set -uo pipefail
expected_hostname="$1"
failures=0

pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

printf '%s\n' '=== IDENTITY ==='
[[ "$(hostname)" == "$expected_hostname" ]] && pass hostname || fail hostname
grep -q '^VERSION_ID="24.04"' /etc/os-release && pass ubuntu-24.04 || fail ubuntu-24.04
check passwordless-sudo sudo -n true
timedatectl show -p Timezone --value | grep -qx Europe/Oslo && pass timezone || fail timezone
uname -a

printf '%s\n' '=== STORAGE ==='
findmnt -no FSTYPE / | grep -qx btrfs && pass root-btrfs || fail root-btrfs
for pair in '/:@' '/home:@home' '/var/lib/docker:@docker' '/.snapshots:@snapshots'; do
  mountpoint="${pair%%:*}"
  subvol="${pair#*:}"
  if findmnt -no OPTIONS "$mountpoint" 2>/dev/null | grep -Eq "(^|,)subvol=/?$subvol(,|$)"; then
    pass "mount-$subvol"
  else
    fail "mount-$subvol"
  fi
done
findmnt -no OPTIONS / | grep -q 'compress=zstd:3' && pass btrfs-compression || fail btrfs-compression
findmnt -no OPTIONS / | grep -q 'noatime' && pass btrfs-noatime || fail btrfs-noatime
if grep -Eq '^md[0-9]+[[:space:]]*:' /proc/mdstat && ! grep -Eq '\[[U_]*_[U_]*\]' /proc/mdstat; then
  pass mdadm-members
else
  fail mdadm-members
fi
if grep -Eq '(resync|recovery|reshape|check)[[:space:]]*=' /proc/mdstat; then
  fail mdadm-still-recovering
else
  pass mdadm-no-recovery
fi
cat /proc/mdstat
sudo -n btrfs device stats / || fail btrfs-device-stats

printf '%s\n' '=== ACCESS ==='
sshd_effective="$(sudo -n sshd -T 2>/dev/null)"
printf '%s\n' "$sshd_effective" | grep -qx 'permitrootlogin no' && pass root-ssh-disabled || fail root-ssh-disabled
printf '%s\n' "$sshd_effective" | grep -qx 'passwordauthentication no' && pass password-ssh-disabled || fail password-ssh-disabled
printf '%s\n' "$sshd_effective" | grep -qx 'kbdinteractiveauthentication no' && pass keyboard-interactive-disabled || fail keyboard-interactive-disabled
sudo -n ufw status | grep -q '^Status: active' && pass ufw-active || fail ufw-active

printf '%s\n' '=== MAINTENANCE ==='
for unit in snapper-timeline.timer snapper-cleanup.timer btrfs-scrub.timer fstrim.timer smartmontools.service unattended-upgrades.service; do
  check "$unit" sudo -n systemctl is-active --quiet "$unit"
done
if [[ -z "$(sudo -n systemctl --failed --no-legend --plain)" ]]; then
  pass systemd-no-failed-units
else
  fail systemd-no-failed-units
  sudo -n systemctl --failed --no-pager
fi
sudo -n snapper -c root list || fail snapper-root

printf '%s\n' '=== DEVELOPMENT ==='
[[ -d "$HOME/dotfiles/.git" ]] && pass dotfiles-clone || fail dotfiles-clone
if [[ -x "$HOME/dotfiles/dotfiles.sh" ]]; then
  (cd "$HOME/dotfiles" && ./dotfiles.sh verify full) && pass dotfiles-full-verify || fail dotfiles-full-verify
else
  fail dotfiles-full-verify
fi
for command_name in git zsh tmux nvim gh uv cargo go fnm node pnpm bun codex claude claudex cli-proxy-api; do
  check "command-$command_name" env -i HOME="$HOME" USER="$USER" PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" /bin/sh -lc "command -v '$command_name'"
done
git -C "$HOME/dotfiles" remote -v 2>/dev/null || true
git -C "$HOME/dotfiles" rev-parse HEAD 2>/dev/null || true
codex --version 2>/dev/null || true
claude --version 2>/dev/null || true

printf 'FAILURES=%s\n' "$failures"
exit "$((failures > 0))"
REMOTE

if "$ssh_bin" -o BatchMode=yes -o ConnectTimeout=5 -o User=root "$host" true >/dev/null 2>&1; then
  printf 'FAIL root-login-succeeds\n' >&2
  exit 1
fi
printf 'PASS root-login-rejected\n'
