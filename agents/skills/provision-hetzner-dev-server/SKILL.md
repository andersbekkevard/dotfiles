---
name: provision-hetzner-dev-server
description: Provision a Hetzner Rescue host as Anders' Ubuntu development server.
disable-model-invocation: true
---

# Provision Hetzner Dev Server

Turn a key-authenticated `root@<ip>` Hetzner Rescue session into a named,
verified development server. Treat each stage as a **checkpoint**: save its
evidence locally and cross its completion criterion before advancing.

## Invocation contract

Require two user-supplied values:

- the Rescue target, exactly `root@<ip>`;
- a lowercase hostname label for the server.

Default the administrator username to `anders`; accept an explicit override.
If either required value is absent, ask for it before connecting. Validate the
inputs with:

```bash
SKILL_DIR="<this skill directory>"
"$SKILL_DIR/scripts/validate-inputs.sh" root@<ip> <hostname> [username]
```

Use the hostname for the remote hostname, local SSH alias, provisioning tmux
session, state directory, snapshot descriptions, and final report. Public DNS
and reverse DNS are separate operations.

Store resumable evidence under:

```bash
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hetzner-provision/<hostname>"
```

Resume from existing evidence when it matches the target and disk identities.
Stop on an SSH-alias collision or evidence belonging to another target.

## Target contract

- Ubuntu 24.04 LTS, upgraded and booted into the installed kernel.
- Two whole disks in mdadm RAID1: 16 GiB swap, 1 GiB ext4 `/boot`, remainder
  Btrfs.
- Btrfs subvolumes `@`, `@home`, `@docker`, and `@snapshots`; mount with
  `noatime,compress=zstd:3`; set No_COW on an empty `/var/lib/docker`.
- `anders` by default, with the Rescue-authorized keys, zsh, and passwordless
  sudo.
- Key-only SSH; `PermitRootLogin no`; UFW allows OpenSSH and denies other
  unsolicited incoming traffic.
- Europe/Oslo, unattended security upgrades, Snapper retention, monthly Btrfs
  scrub, weekly TRIM, SMART monitoring, and mdadm monitoring.
- `~/dotfiles` on the requested revision (default: repository HEAD), with
  `./dotfiles.sh install full --yes` and `./dotfiles.sh verify full` both successful.
- Official Claude Code, Codex, and `claudex` installed; machine-local logins
  complete.
- Baseline and post-dotfiles root snapshots plus read-only home snapshots.

Local snapshots are rollback, not backup. Report off-machine backup as
unconfigured unless the user supplies a destination and credentials.

## 1. Establish the Rescue checkpoint

Create `STATE_DIR`, record the target and requested hostname, and run:

```bash
"$SKILL_DIR/scripts/preflight.sh" root@<ip> "$STATE_DIR"
```

Read the complete report. Confirm all of the following from live evidence:

- the remote environment identifies itself as Hetzner Rescue;
- key authentication works without a prompt;
- exactly two candidate whole disks exist;
- both disks have no partitions or filesystem signatures;
- no active md array uses them;
- the selected Ubuntu 24.04 image exists;
- boot mode, disk serials, SMART/NVMe health, IPs, RAM, and authorized-key
  fingerprints are recorded.

Record Rescue host-key fingerprints before installation. The checkpoint is
complete only when the script exits zero and both disk identities are
unambiguous. Existing data or a different topology requires fresh user
authorization.

## 2. Cross the destructive checkpoint

Read `DRIVE1` and `DRIVE2` from the preflight report and render the exact
installer configuration:

```bash
"$SKILL_DIR/scripts/render-installimage-config.sh" \
  <hostname> <drive1> <drive2> "$STATE_DIR/installimage.conf"
```

Show the user the IP, hostname, disk paths/models/serials, blank-disk evidence,
complete configuration, and SHA-256. Ask once for explicit confirmation that
both named disks may be erased. This confirmation is the authority to run
`installimage`; earlier intent is not.

Copy the hashed configuration to `/root`, then run `installimage -a -c ...`
inside a Rescue-side tmux session named `provision-<hostname>`. Tee its output
and preserve its exit status. Inspect `/root/debug.txt`, the generated fstab,
subvolumes, md arrays, and GRUB installation. For Legacy/CSM, use `fdisk` or
`parted` as partition-table evidence and require successful GRUB installation
on both physical disks. Treat `sgdisk`'s in-memory MBR conversion as
non-authoritative.

The checkpoint is complete only when installimage exits zero and both disks,
all arrays, the root subvolume, and both GRUB installs are accounted for. On
failure, follow [recovery.md](references/recovery.md) before retrying or
rebooting.

## 3. Establish the operating-system checkpoint

Reboot and probe SSH for up to 15 minutes; physical POST commonly takes several
minutes. Record the expected host-key transition, remove only the old target's
known-host entries, and record the installed host keys before reconnecting.

As root on the installed OS:

1. Confirm Ubuntu 24.04 and the expected RAID/Btrfs topology.
2. Set the requested hostname and `/etc/hosts` entry.
3. Create the administrator, copying `/root/.ssh/authorized_keys` with strict
   ownership and permissions. Install a validated `NOPASSWD` sudoers drop-in.
4. Relocate the installer-created `@snapshots` mount from `/snapshots` to
   `/.snapshots`, add the Btrfs mount options, and set No_COW on the empty
   Docker subvolume.
5. Upgrade the OS and install `btrfs-progs`, `snapper`, `smartmontools`,
   `nvme-cli`, `mdadm`, `btrfsmaintenance`, `unattended-upgrades`, `ufw`, and
   `tmux`.
6. Configure the maintenance contract and create the post-install snapshots.

Keep long-running work in remote tmux. Before hardening SSH, open a separate
fresh login as the administrator and prove `sudo -n true`. Then install an
`sshd_config.d` drop-in for key-only administrator access, validate with
`sshd -t`, reload SSH, enable UFW, and prove another fresh administrator login.
Only then verify root SSH is rejected.

Reboot after upgrades and fstab changes. The checkpoint is complete when the
new kernel is running, every expected mount is live, all md members are `[UU]`,
administrator SSH and non-interactive sudo work, and root/password SSH are
disabled.

## 4. Establish the development checkpoint

Inside remote tmux as the administrator:

1. Clone `https://github.com/andersbekkevard/dotfiles.git` to `~/dotfiles`.
2. Record the commit and run `./dotfiles.sh install full --yes`, preserving its
   full log and exit status. Retry only understood transient failures; repair a reproducible
   dotfiles defect at its source rather than weakening verification.
3. Run `./dotfiles.sh verify full` in a clean session.
4. Install Claude Code from Anthropic's current official Linux instructions;
   the dotfiles `full` profile installs Codex and `claudex`, not ordinary
   `claude`.
5. Read `~/dotfiles/docs/claudex.md`, then initiate the documented Codex,
   Claude, and CLIProxyAPI authentication flows. Give the user the minimum
   browser/device-code handoff and continue after approval.
6. Create post-dotfiles root and read-only home snapshots.

The checkpoint is complete only when both setup commands exit zero, `claude`,
`codex`, and `claudex` resolve from clean login and stable non-login shells,
their versions are recorded, and every machine-local login reports success.

## 5. Establish the access and acceptance checkpoint

Inspect effective local SSH configuration with `ssh -G <hostname>`. If the
alias is free, add a narrowly owned entry that sets the IP, administrator,
`~/.ssh/id_ed25519`, `IdentitiesOnly yes`, and keepalive settings. Preserve the
user's existing SSH ownership pattern and prove `ssh <hostname>` works.

Wait for initial md resync to finish, then run:

```bash
"$SKILL_DIR/scripts/verify-host.sh" <administrator>@<ip> <hostname>
```

Resolve every failed check. Finish with a report containing:

- hostname, IPs, OS, kernel, CPU, RAM, and timezone;
- disk models/serials, SMART wear/error baseline, RAID state, and Btrfs usage;
- mount/subvolume/options evidence and snapshot list;
- SSH, sudo, UFW, updates, services, and timers;
- dotfiles remote, commit, setup/verify results, and CLI versions/auth status;
- local SSH alias and the exact login command;
- state-directory path, installer-config hash, and recovery route;
- explicit off-machine-backup status.

Completion requires a zero exit from `verify-host.sh`, no failed systemd units,
no active RAID recovery, successful CLI authentication, and a fresh `ssh
<hostname>` session. A pending browser approval is an authentication handoff,
not completion.
