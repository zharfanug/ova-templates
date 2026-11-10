#!/usr/bin/env bash
# OpenSSH server: config files root-only (CIS), group ssh for AllowGroups,
# sshd from ssh.service (not ssh.socket, so the Port setting applies).
# Host keys are removed in 90-cleanup.sh and created at first boot.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

chmod 0600 "$TARGET/etc/ssh/sshd_config" "$TARGET"/etc/ssh/sshd_config.d/*.conf

# AllowGroups sudo ssh: users outside sudo need group ssh to log in.
in_chroot getent group ssh >/dev/null || in_chroot groupadd --system ssh

in_chroot systemctl enable ssh.service
in_chroot systemctl disable ssh.socket
