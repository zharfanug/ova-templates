#!/usr/bin/env bash
# Swap disk (disk 2): swap-grow re-creates the swap area at boot when the
# disk was enlarged (unit and script from the rootfs overlay).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

in_chroot systemctl enable swap-grow.service
