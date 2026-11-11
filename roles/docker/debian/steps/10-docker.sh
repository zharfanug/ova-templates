#!/usr/bin/env bash
# Docker: services enabled (they start at boot, not in the build), rule
# file modes. Settings come from the rootfs overlay (daemon.json, sysctl,
# nftables forward rules, logrotate, audit, AIDE, admin group).
set -euo pipefail
# shellcheck source=../../../../os/debian/steps/lib.sh
. "$REPO_ROOT/os/debian/steps/lib.sh"

in_chroot systemctl enable containerd.service docker.service docker.socket
chmod 0640 "$TARGET/etc/audit/rules.d/60-docker.rules"
