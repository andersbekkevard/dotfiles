# Recovery branches

Read the branch matching the failed checkpoint. Preserve logs and disk
identities before changing state.

## installimage exits nonzero

Remain in Rescue. Save `/root/debug.txt`, the installimage log, generated
configuration, `lsblk -f`, `fdisk -l`, `/proc/mdstat`, and mount output to the
local state directory. Classify the failure as configuration validation,
download/extraction, RAID, filesystem, or bootloader. Render a new
configuration when its content changes and obtain a new destructive
confirmation for any disk-set change. A byte-identical retry after a clearly
transient transport failure may reuse the existing confirmation.

## Installed system does not answer SSH

Probe ping and TCP/22 for 15 minutes before treating physical POST as failed.
If unavailable after the deadline, activate Hetzner Rescue, reboot, and inspect
the installed system read-only first:

```bash
cat /proc/mdstat
mdadm --assemble --scan
mount -o ro,subvol=@ /dev/md2 /mnt
cat /mnt/etc/fstab
cat /mnt/boot/grub/grub.cfg
```

Confirm actual device names from `lsblk`; the example `/dev/md2` is not an
instruction. Mount `/boot`, bind `/dev`, `/proc`, `/sys`, and `/run`, then
chroot only when a repair is identified. Reinstall BIOS GRUB to both physical
disks for a Legacy machine; use the EFI path only when `/sys/firmware/efi`
proved UEFI at preflight.

## SSH host key changes

A host-key change is expected once when Rescue is replaced by Ubuntu. Record
the Rescue fingerprint, remove only entries for the target IP, accept the new
key, and record its fingerprint. Any later unexplained change is an identity
failure and stops the run.

## Administrator access fails

Keep the root session open. Check the administrator's home ownership,
`~/.ssh` mode `0700`, `authorized_keys` mode `0600`, sudoers syntax with
`visudo -cf`, `sshd -t`, and the effective `sshd -T` policy. Establish a fresh
administrator login and `sudo -n true` before applying SSH hardening.

If root has already been disabled, boot Rescue, assemble the arrays, mount the
root `@` subvolume, and repair the key or sshd drop-in from the mounted system.

## RAID is degraded or rebuilding

`[UU]` means both RAID1 members are present. An underscore identifies the
missing member. Save `/proc/mdstat`, `mdadm --detail` for every array, SMART
data, and kernel storage errors. A healthy initial resync may continue while
configuration proceeds, but final acceptance waits for it to finish. A disk
with media errors or a disappearing member requires Hetzner hardware handling,
not repeated filesystem repair.

## Btrfs rollback

Snapper root snapshots cover the root subvolume. Home snapshots are separate,
read-only manual subvolumes. Inspect the exact snapshot and current mount graph
before rollback. Boot Rescue for a non-booting system, mount the top-level
Btrfs tree with `subvolid=5`, preserve the current `@`, and replace it with a
writable snapshot of the chosen known-good root. Regenerate GRUB when kernel or
boot paths changed.

The Btrfs filesystem sits on one mdadm device. Checksums detect corruption, but
Btrfs does not see two independent data copies and therefore cannot select a
good mirror itself. RAID1 availability, local snapshots, and off-machine
backup solve different failures.

## Dotfiles or runtime setup fails

Keep the remote tmux session and full log. Rerun only after distinguishing a
transient download failure from a reproducible setup defect. The setup is
idempotent; the acceptance gate remains `./setup.sh full` followed by
`./setup.sh --verify full`, both exiting zero. Fix a reproducible defect in the
dotfiles source and rerun rather than suppressing a required command.

## OAuth is pending

Keep the machine configured and report an authentication handoff. Initiate the
official device/browser flow, give the user its URL or code, and resume after
approval. Authentication state stays machine-local; copying tokens from the
control machine is a separate, explicit secrets decision.
