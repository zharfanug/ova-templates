#!/usr/bin/env bash
# Raw disk image: GPT with ESP, swap and Btrfs; attached as a loop device.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

swap_end=$((1 + ESP_MIB + SWAP_GB * 1024))

log "image $IMAGE (${DISK_GB} GiB, sparse)"
rm -f "$IMAGE"
truncate -s "${DISK_GB}G" "$IMAGE"

parted -s -a optimal "$IMAGE" -- \
  mklabel gpt \
  mkpart esp fat32 1MiB "$((1 + ESP_MIB))MiB" \
  set 1 esp on \
  mkpart swap linux-swap "$((1 + ESP_MIB))MiB" "${swap_end}MiB" \
  mkpart rootfs btrfs "${swap_end}MiB" 100%
parted -s "$IMAGE" unit MiB print

loop=$(losetup --find --show --partscan "$IMAGE")
log "attached $loop"
# Recorded first, so a failure below still detaches it.
echo "LOOP=$loop" > "$STATE/devs.env"

for n in 1 2 3; do
  for _ in $(seq 50); do
    [ -b "${loop}p$n" ] && break
    sleep 0.1
  done
  [ -b "${loop}p$n" ] || die "${loop}p$n did not appear"
done

cat >> "$STATE/devs.env" <<EOF
ESP_DEV=${loop}p1
SWAP_DEV=${loop}p2
BTRFS_DEV=${loop}p3
EOF

mkfs.vfat -F 32 -n EFI "${loop}p1"
mkswap -L swap "${loop}p2"
mkfs.btrfs -f -L rootfs "${loop}p3"
