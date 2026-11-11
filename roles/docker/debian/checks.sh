# Role docker: build checks, sourced by os/debian/steps/80-checks.sh
# (need, in_chroot, $TARGET available). Listed in docs/checks.md.
# shellcheck shell=bash

# Apt repository and packages (Docker's install guide)
need "docker: key /etc/apt/keyrings/docker.asc 0644" \
  test "$(stat -c %a "$TARGET/etc/apt/keyrings/docker.asc")" = 644
need "docker: apt source download.docker.com, signed by the key" \
  sh -c "grep -qx 'URIs: https://download.docker.com/linux/debian' '$TARGET/etc/apt/sources.list.d/docker.sources' \
         && grep -qx 'Signed-By: /etc/apt/keyrings/docker.asc' '$TARGET/etc/apt/sources.list.d/docker.sources'"
for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ca-certificates curl; do
  need "docker: $pkg installed" in_chroot dpkg-query -W -f='${Status}' "$pkg"
done
for u in containerd.service docker.service docker.socket; do
  need "docker: $u enabled" test "$(in_chroot systemctl is-enabled "$u" 2>/dev/null)" = enabled
done
need "docker: group docker" in_chroot getent group docker

# Settings
need "docker: daemon.json valid, settings as designed" python3 -c "
import json, sys
d = json.load(open('$TARGET/etc/docker/daemon.json'))
want = {'log-driver': 'json-file', 'live-restore': True, 'no-new-privileges': True,
        'userland-proxy': False, 'icc': False}
sys.exit(any(d.get(k) != v for k, v in want.items()))"
need "docker: sysctl ip_forward = 1 (CIS deviation, overrides 60-cis)" \
  grep -qx 'net.ipv4.ip_forward = 1' "$TARGET/etc/sysctl.d/70-docker.conf"
need "docker: nftables forwards the Docker bridges" \
  test "$(grep -cE '^(iif|oif)name "(docker0|br-\*)" accept$' "$TARGET/etc/nftables.d/std-forward.nft")" -eq 4
need "docker: nftables.conf still valid with the forward rules" in_chroot nft -c -f /etc/nftables.conf
need "docker: container logs kept 14 days (logrotate valid)" \
  sh -c "grep -qP '^\trotate 14$' '$TARGET/etc/logrotate.d/docker-containers' && chroot '$TARGET' logrotate -d /etc/logrotate.d/docker-containers"
need "docker: audit rules 60-docker 0640" test "$(stat -c %a "$TARGET/etc/audit/rules.d/60-docker.rules")" = 640
need "docker: AIDE watches /etc/docker" grep -qx '/etc/docker Full' "$TARGET/etc/aide/aide.conf.d/70_aide_docker"
need "docker: AIDE config valid with the role rules" in_chroot aide --config /etc/aide/aide.conf --config-check
need "docker: admin joins group docker (vapp-seed)" \
  grep -qx docker "$TARGET/etc/vapp-seed/admin-groups.d/docker"
