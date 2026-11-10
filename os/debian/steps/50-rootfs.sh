#!/usr/bin/env bash
# Copy the file overlays onto the image, later ones win:
#   common/rootfs → os/<os>/rootfs → platforms/<platform>/rootfs
#   → roles/<role>/<os>/rootfs (in ROLES order)
# Files become root:root, 0644 (0755 if executable in the repo),
# directories 0755. Steps set other modes where needed.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

overlays=(
  "$REPO_ROOT/common/rootfs"
  "$REPO_ROOT/os/$OS/rootfs"
  "$REPO_ROOT/platforms/$PLATFORM/rootfs"
)
for role in $ROLES; do
  overlays+=("$REPO_ROOT/roles/$role/$OS/rootfs")
done

for dir in "${overlays[@]}"; do
  [ -d "$dir" ] || continue
  log "overlay ${dir#"$REPO_ROOT"/}"
  rsync -rlt --itemize-changes --chown=root:root \
    --chmod=D755,Fa=rX,Fu+w "$dir/" "$TARGET/"
done
