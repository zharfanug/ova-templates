#!/usr/bin/env bash
# GRUB for UEFI at the removable path (EFI/BOOT/BOOTX64.EFI): boots
# without NVRAM entries, so no firmware setup is needed on import.
# Runs after the rootfs overlay, so /etc/default/grub.d/ (kernel options)
# is in place.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
load_devs

# Boot entries need no password; editing them and the GRUB console do
# (the superuser password is set per VM at first boot).
sed -i 's/^CLASS="--class gnu-linux --class gnu --class os"$/CLASS="--class gnu-linux --class gnu --class os --unrestricted"/' \
  "$TARGET/etc/grub.d/10_linux"
grep -q '^CLASS=".*--unrestricted"$' "$TARGET/etc/grub.d/10_linux" \
  || die "10_linux: CLASS line not found"

in_chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi \
  --bootloader-id=debian --no-nvram --removable
in_chroot update-grub

# Inside the builder, grub-mkconfig may see the loop device instead of
# the filesystem UUID. Point the kernel at the UUID, as fstab does.
btrfs_uuid=$(blkid -s UUID -o value "$BTRFS_DEV")
sed -i -E "s#(^\s*linux\s+\S+\s+)root=\S+#\1root=UUID=$btrfs_uuid#" \
  "$TARGET/boot/grub/grub.cfg"
chmod 0600 "$TARGET/boot/grub/grub.cfg"
grep -E '^\s*linux\s' "$TARGET/boot/grub/grub.cfg"
