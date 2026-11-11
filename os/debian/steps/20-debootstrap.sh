#!/usr/bin/env bash
# Base system, fstab, hostname, apt sources.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
load_devs

debootstrap --arch="$ARCH" --variant=minbase "$SUITE" "$TARGET" "$MIRROR"

btrfs_uuid=$(blkid -s UUID -o value "$BTRFS_DEV")
esp_uuid=$(blkid -s UUID -o value "$ESP_DEV")
swap_uuid=$(blkid -s UUID -o value "$SWAP_DEV")

{
  echo "# <file system> <mount point> <type> <options> <dump> <pass>"
  for entry in "${SUBVOLS[@]}"; do
    read -r name path extra <<< "$entry"
    echo "UUID=$btrfs_uuid $path btrfs $(subvol_opts "$name" "$path" "${extra:-}") 0 0"
  done
  echo "tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0"
  echo "UUID=$esp_uuid /boot/efi vfat umask=0077 0 1"
  # Swap disk (disk 2): the VM still boots, without swap, when it is
  # removed; swap-grow re-creates it at the new size after it is enlarged.
  echo "UUID=$swap_uuid none swap $SWAP_OPTS 0 0"
} > "$TARGET/etc/fstab"
cat "$TARGET/etc/fstab"

# No hibernation: the initramfs never waits for a resume device.
mkdir -p "$TARGET/etc/initramfs-tools/conf.d"
echo "RESUME=none" > "$TARGET/etc/initramfs-tools/conf.d/resume"

echo "$IMAGE_HOSTNAME" > "$TARGET/etc/hostname"
cat > "$TARGET/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $IMAGE_HOSTNAME

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

rm -f "$TARGET/etc/apt/sources.list"
cat > "$TARGET/etc/apt/sources.list.d/debian.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: $SUITE $SUITE-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $SECURITY_MIRROR
Suites: $SUITE-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
