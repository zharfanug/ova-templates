#!/usr/bin/env bash
# Networking is ifupdown + dhcpcd (networking.service, enabled by the
# ifupdown package). systemd-networkd ships with systemd: keep it off so
# only one DHCP client runs per NIC.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

in_chroot systemctl disable systemd-networkd.service systemd-networkd.socket \
  systemd-networkd-wait-online.service

# IPv6 is disabled (sysctl.d/60-cis.conf): dhcpcd would still try to add
# a link-local address and fail ("ipv6_addaddr1: Permission denied").
grep -qx ipv4only "$TARGET/etc/dhcpcd.conf" || cat >> "$TARGET/etc/dhcpcd.conf" <<'CONF'

# IPv4 only (IPv6 is disabled in /etc/sysctl.d/60-cis.conf).
ipv4only
CONF
