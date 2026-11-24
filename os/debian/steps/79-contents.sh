#!/usr/bin/env bash
# What the image contains (OS release, kernel, the roles' core packages):
# <image>.contents.json next to the image, not inside it. make-ova.py turns
# it into <ova>.manifest.json with the product version (build and release).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

out="${IMAGE%.img}.contents.json"
# shellcheck disable=SC2086  # ROLES is a space-separated list
python3 "$REPO_ROOT/os/$OS/contents.py" "$TARGET" "$TEMPLATE" $ROLES > "$out"
cat "$out"
