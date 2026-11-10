#!/usr/bin/env bash
# Btrfs subvolumes, mounted with their options on $TARGET, plus the ESP.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
load_devs

top="$STATE/btrfs-top"
mkdir -p "$top"
mount -o subvolid=5 "$BTRFS_DEV" "$top"
for entry in "${SUBVOLS[@]}"; do
  read -r name _ <<< "$entry"
  btrfs subvolume create "$top/$name"
done
umount "$top"

mkdir -p "$TARGET"
for entry in "${SUBVOLS[@]}"; do
  read -r name path extra <<< "$entry"
  mkdir -p "$TARGET$path"
  mount -o "$(subvol_opts "$name" "$path" "${extra:-}")" "$BTRFS_DEV" "$TARGET$path"
done

# apt's _apt sandbox needs these during the build already.
for d in "${STICKY_DIRS[@]}"; do
  chmod 1777 "$TARGET$d"
done

mkdir -p "$TARGET/boot/efi"
mount -o umask=0077 "$ESP_DEV" "$TARGET/boot/efi"

findmnt -R "$TARGET"
