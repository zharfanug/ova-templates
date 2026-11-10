#!/usr/bin/env bash
# Remove per-VM identity and build leftovers, discard free space, unmount.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# machine-id: empty file = generated at first boot (systemd).
: > "$TARGET/etc/machine-id"
rm -f "$TARGET/var/lib/dbus/machine-id"
mkdir -p "$TARGET/var/lib/dbus"
ln -s /etc/machine-id "$TARGET/var/lib/dbus/machine-id"

# SSH host keys are generated on first boot.
rm -f "$TARGET"/etc/ssh/ssh_host_*

in_chroot apt-get clean
rm -rf "$TARGET"/var/lib/apt/lists/*
rm -f "$TARGET/usr/sbin/policy-rc.d" "$TARGET/etc/resolv.conf"
# dhcpcd writes resolv.conf at boot (no systemd-resolved).
echo "# Written by dhcpcd at boot." > "$TARGET/etc/resolv.conf"
rm -rf "$TARGET"/tmp/* "$TARGET"/var/tmp/*
find "$TARGET/var/log" -type f -exec truncate -s 0 {} +

chroot_umount

# Freed blocks go back to the sparse image (smaller VMDK).
fstrim -v "$TARGET/boot/efi"
fstrim -v "$TARGET"

umount -R "$TARGET"
