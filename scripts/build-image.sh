#!/usr/bin/env bash
# Build the raw disk image for one template and platform. Runs inside the
# builder container (called by scripts/build.sh).
#
# Usage: scripts/build-image.sh <template> <platform> <outdir>
#   → <outdir>/<os>-<ver>[-<role>]-<arch>-<firmware>-<platform>.img       (disk 1)
#   → <outdir>/<os>-<ver>[-<role>]-<arch>-<firmware>-<platform>-swap.img  (disk 2)
#
# Runs os/<os>/steps/NN-*.sh in order. The image is mounted on $TARGET
# while the steps run; mounts and the loop device are always released at
# the end, also on failure.

# shellcheck source-path=SCRIPTDIR
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/scripts/lib/common.sh"

[ $# -eq 3 ] || die "usage: $0 <template> <platform> <outdir>"
template="$1"
PLATFORM="$2"
outdir="$3"

load_env
load_template "$template"
template_supports "$PLATFORM" || die "$template does not support platform '$PLATFORM'"

vars="$REPO_ROOT/os/$OS/$VER/vars.env"
[ -f "$vars" ] || die "no os/$OS/$VER/vars.env"
set -a
# shellcheck disable=SC1090
. "$vars"
set +a

mkdir -p "$outdir"
IMAGE="$(cd "$outdir" && pwd)/$(image_file "$PLATFORM")"
SWAP_IMAGE="$(cd "$outdir" && pwd)/$(swap_image_file "$PLATFORM")"
IMAGE_HOSTNAME="${OS}-${VER}-template"
TARGET=/mnt/target
STATE="$(mktemp -d)"
export REPO_ROOT PLATFORM IMAGE SWAP_IMAGE IMAGE_HOSTNAME TARGET STATE

teardown() {
  local rc=$?
  if mountpoint -q "$TARGET" || findmnt -R "$TARGET" >/dev/null 2>&1; then
    log "unmounting $TARGET"
    umount -R "$TARGET" 2>/dev/null || umount -R -l "$TARGET" || true
  fi
  if mountpoint -q "$STATE/btrfs-top" 2>/dev/null; then
    umount "$STATE/btrfs-top" || true
  fi
  if [ -f "$STATE/devs.env" ]; then
    # shellcheck disable=SC1091
    . "$STATE/devs.env"
    for l in ${LOOP:-} ${SWAP_LOOP:-}; do
      if losetup "$l" >/dev/null 2>&1; then
        log "detaching $l"
        losetup -d "$l" || true
      fi
    done
  fi
  rm -rf "$STATE"
  exit "$rc"
}
trap teardown EXIT

steps_dir="$REPO_ROOT/os/$OS/steps"
[ -d "$steps_dir" ] || die "no os/$OS/steps/"

log "image $IMAGE_NAME for $PLATFORM"
for step in "$steps_dir"/[0-9][0-9]-*.sh; do
  log "=== step ${step#"$REPO_ROOT"/}"
  bash "$step"
done

log "image done: $IMAGE"
log "allocated: $(du -h "$IMAGE" | cut -f1) of $(du -h --apparent-size "$IMAGE" | cut -f1)"
log "swap disk: $SWAP_IMAGE ($(du -h --apparent-size "$SWAP_IMAGE" | cut -f1))"
