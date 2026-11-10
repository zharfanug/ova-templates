#!/usr/bin/env bash
# Logs and monitoring: sudo log rotation (rootfs overlay), sysstat enabled
# (Debian ships it disabled; data in /var/log/sysstat, kept 7 days).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

sed -i 's/^ENABLED=.*/ENABLED="true"/' "$TARGET/etc/default/sysstat"
in_chroot systemctl enable sysstat.service sysstat-collect.timer \
  sysstat-summary.timer sysstat-rotate.timer
