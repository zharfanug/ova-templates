#!/usr/bin/env bash
# nftables (template table inet base-nft, /etc/nftables.conf + nftables.d/)
# and fail2ban (sshd jail, bans in its own table inet f2b-table).
# Config files come from the rootfs overlay.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# Syntax only: -c never touches the running ruleset (the builder shares
# the host's network namespace).
in_chroot nft -c -f /etc/nftables.conf
in_chroot fail2ban-client --test >/dev/null

in_chroot systemctl enable nftables.service fail2ban.service
