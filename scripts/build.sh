#!/usr/bin/env bash
# Build OVAs for one template.
#
# Usage: scripts/build.sh <template> [platform...]
#   <template>  name of a file in templates/ without .env,
#               e.g. debian-13-amd64-efi
#   platform    vmware, proxmox, ... (default: every platform in the
#               template's PLATFORMS)
#
# Each run gets an ID (YYYYMMDDhhmm, start time):
#   build/<ID>/  images and OVAs
#   logs/<ID>/   all logs (never deleted by this script)
#
# At the start, old build folders are pruned: the 3 newest builds and the
# 2 newest finished ones (with an OVA) are kept.
#
# Environment:
#   ID=<YYYYMMDDhhmm>  reuse an existing build/<ID>/ and logs/<ID>/
#                      instead of starting a new run

# shellcheck source-path=SCRIPTDIR
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=lib/ids.sh
. "$REPO_ROOT/scripts/lib/ids.sh"

usage() {
  sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0" >&2
  exit 2
}

[ $# -ge 1 ] || usage
case "$1" in -h|--help) usage ;; esac

template="$1"
shift

load_env
load_template "$template"

if [ $# -gt 0 ]; then
  platforms=("$@")
else
  # shellcheck disable=SC2153  # PLATFORMS comes from the template
  read -r -a platforms <<< "$PLATFORMS"
fi
for p in "${platforms[@]}"; do
  template_supports "$p" || die "$template does not support platform '$p' (PLATFORMS=\"$PLATFORMS\")"
done

cd "$REPO_ROOT"

if [ -n "${ID:-}" ]; then
  valid_id "$ID" || die "ID must look like YYYYMMDDhhmm, got '$ID'"
  [ -d "build/$ID" ] || die "no build/$ID/ to reuse"
else
  ID="$(new_id)"
  [ ! -e "build/$ID" ] || die "build/$ID/ already exists (one build per minute; set ID=$ID to reuse it)"
fi
# The ID is also {timestamp} in PRODUCT_VERSION (same for every platform).
export ID

LOGDIR="logs/$ID"
OUTDIR="build/$ID"
mkdir -p "$LOGDIR" "$OUTDIR"

exec > >(tee -a "$LOGDIR/build.log") 2>&1

log "template:  $template"
log "platforms: ${platforms[*]}"
log "ID:        $ID"
log "output:    $OUTDIR/"
log "logs:      $LOGDIR/"

# The builder runs as root, so files in build/ are root-owned: deleting
# and cleaning up is done inside the container too.
in_builder() { BUILDER_NO_BUILD=1 "$REPO_ROOT/docker/run.sh" "$@" </dev/null; }

log "builder image"
docker build --network "${BUILDER_NETWORK:-host}" \
  -t "${BUILDER_IMAGE:-ova-templates-builder:latest}" \
  -f docker/Dockerfile docker > "$LOGDIR/docker-build.log" 2>&1 \
  || die "builder image failed (see $LOGDIR/docker-build.log)"

prune=$(builds_to_prune "$ID")
if [ -n "$prune" ]; then
  for d in $prune; do
    log "pruning build/$d/"
    echo "$(date '+%F %T') pruned build/$d/" >> "$LOGDIR/prune.log"
  done
  # shellcheck disable=SC2086
  in_builder sh -c 'cd build && rm -rf -- "$@"' sh $prune
fi

# A failed image build can leave its image attached (loop device plus
# kpartx partition mappings). Detach only the loop devices backed by this
# run's images, matched by inode.
cleanup_loops() {
  local img inodes=""
  for img in "$OUTDIR"/*.img; do
    [ -f "$img" ] && inodes="$inodes $(stat -c %i "$img")"
  done
  [ -n "$inodes" ] || return 0
  # shellcheck disable=SC2016,SC2086
  in_builder sh -c '
    for ino in "$@"; do
      for loop in $(losetup -a | awk -F: -v ino=":$ino" "index(\$0, ino \" (\") {print \$1}"); do
        echo "detaching $loop (image inode $ino)"
        kpartx -d "$loop" || true
        for m in $(dmsetup ls 2>/dev/null | awk -v n="${loop#/dev/}p" "index(\$1, n) == 1 {print \$1}"); do
          dmsetup remove "$m" && echo "removed mapping $m"
        done
        losetup -d "$loop" && echo "detached $loop"
      done
    done
  ' sh $inodes >> "$LOGDIR/cleanup.log" 2>&1 || true
}

# Output is written as root inside the builder; hand it to the caller.
give_back() {
  # shellcheck disable=SC2016  # expanded inside the container
  in_builder sh -c 'chown -R "$HOST_UID:$HOST_GID" "$1"' sh "$OUTDIR" || true
}

fail() {
  log "FAILED: $1 (see $2)"
  cleanup_loops
  give_back
  [ -s "$LOGDIR/cleanup.log" ] && log "loop devices of this run cleaned up (see $LOGDIR/cleanup.log)"
  exit 1
}

for p in "${platforms[@]}"; do
  img="$(image_file "$p")"
  ova="$(ova_file "$p")"

  log "[$p] image -> $OUTDIR/$img"
  in_builder scripts/build-image.sh "$template" "$p" "$OUTDIR" \
    > "$LOGDIR/image-$p.log" 2>&1 \
    || fail "[$p] image" "$LOGDIR/image-$p.log"

  log "[$p] ova -> $OUTDIR/$ova"
  in_builder python3 scripts/make-ova.py "$template" "$p" "$OUTDIR" \
    > "$LOGDIR/ova-$p.log" 2>&1 \
    || fail "[$p] ova" "$LOGDIR/ova-$p.log"
done

give_back

log "done"
for p in "${platforms[@]}"; do
  log "  $OUTDIR/$(ova_file "$p")"
done
