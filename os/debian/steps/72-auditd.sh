#!/usr/bin/env bash
# auditd: rule files from the rootfs overlay (etc/audit/rules.d/), the
# setuid/setgid rules generated here, auditd.conf values, log archive.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

rules="$TARGET/etc/audit/rules.d"

# Debian's audit.rules sorts after 99-finalize.rules: its -D would run
# after the -e 2 lock.
rm -f "$rules/audit.rules"

# CIS "privileged commands": every setuid/setgid program in the image.
{
  echo "## Generated at build time: setuid/setgid programs (CIS privileged)."
  in_chroot find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | sort |
  while read -r prog; do
    for arch in b64 b32; do
      echo "-a always,exit -F arch=$arch -F path=$prog -F perm=x -F auid>=1000 -F auid!=unset -F key=privileged"
    done
  done
} > "$rules/31-privileged.rules"
chmod 0640 "$rules"/*.rules

# Watched (ssh-keys); a watch on a missing folder stops the whole rule load.
install -d -o root -g root -m 0700 "$TARGET/root/.ssh"

# auditd.conf: CIS values; warn at 15% free, halt at 3% (whole disk).
sed -i \
  -e 's/^log_group = .*/log_group = root/' \
  -e 's/^max_log_file = .*/max_log_file = 200/' \
  -e 's/^max_log_file_action = .*/max_log_file_action = keep_logs/' \
  -e 's/^space_left = .*/space_left = 15%/' \
  -e 's|^space_left_action = .*|space_left_action = exec /usr/local/sbin/audit-space-warn|' \
  -e 's/^admin_space_left = .*/admin_space_left = 3%/' \
  -e 's/^admin_space_left_action = .*/admin_space_left_action = halt/' \
  -e 's/^disk_full_action = .*/disk_full_action = halt/' \
  -e 's/^disk_error_action = .*/disk_error_action = halt/' \
  "$TARGET/etc/audit/auditd.conf"

chmod 0750 "$TARGET/usr/local/sbin/audit-archive" "$TARGET/usr/local/sbin/audit-space-warn"
in_chroot systemctl enable auditd.service audit-archive.timer
