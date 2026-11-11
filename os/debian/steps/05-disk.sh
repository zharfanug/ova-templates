#!/usr/bin/env bash
# Raw disk images, each attached as a loop device:
#   disk 1 ($IMAGE):      GPT with ESP and Btrfs (last, so it can grow)
#   disk 2 ($SWAP_IMAGE): swap on the whole disk, no partition table
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

log "image $IMAGE (${DISK_GB} GiB, sparse)"
rm -f "$IMAGE" "$SWAP_IMAGE"
truncate -s "${DISK_GB}G" "$IMAGE"

parted -s -a optimal "$IMAGE" -- \
  mklabel gpt \
  mkpart esp fat32 1MiB "$((1 + ESP_MIB))MiB" \
  set 1 esp on \
  mkpart rootfs btrfs "$((1 + ESP_MIB))MiB" 100%
parted -s "$IMAGE" unit MiB print

loop=$(losetup --find --show --partscan "$IMAGE")
log "attached $loop"
# Recorded first, so a failure below still detaches it.
echo "LOOP=$loop" > "$STATE/devs.env"

for n in 1 2; do
  for _ in $(seq 50); do
    [ -b "${loop}p$n" ] && break
    sleep 0.1
  done
  [ -b "${loop}p$n" ] || die "${loop}p$n did not appear"
done

log "swap disk $SWAP_IMAGE (${SWAP_GB} GiB, sparse)"
truncate -s "${SWAP_GB}G" "$SWAP_IMAGE"
swap_loop=$(losetup --find --show "$SWAP_IMAGE")
log "attached $swap_loop"

cat >> "$STATE/devs.env" <<EOF
SWAP_LOOP=$swap_loop
ESP_DEV=${loop}p1
BTRFS_DEV=${loop}p2
SWAP_DEV=$swap_loop
EOF

mkfs.vfat -F 32 -n EFI "${loop}p1"
mkfs.btrfs -f -L rootfs "${loop}p2"
mkswap -L swap "$swap_loop"
