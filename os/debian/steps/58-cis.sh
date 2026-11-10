#!/usr/bin/env bash
# CIS base hardening. Files (sysctl, modprobe, limits, pwquality, PAM
# profiles, sudoers, TMOUT, journald, cron.allow, kernel options) come
# from the rootfs overlay; this step sets modes and edits system files.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# --- PAM: password quality, lockout, history, umask 027 ---------------------
# pam-auth-update writes the common-* files from /usr/share/pam-configs/.
in_chroot pam-auth-update --enable pwquality faillock faillock_notify pwhistory umask-027

grep -qE '^deny = 5$' "$TARGET/etc/security/faillock.conf" \
  || printf '\n# CIS: lock after 5 failed password logins, for 15 minutes.\ndeny = 5\nunlock_time = 900\n' \
     >> "$TARGET/etc/security/faillock.conf"

# su only for members of group sudo (CIS wants a dedicated empty group).
grep -q '^auth *required *pam_wheel.so use_uid group=sudo' "$TARGET/etc/pam.d/su" \
  || sed -i '/^auth[[:space:]]*sufficient[[:space:]]*pam_rootok.so/a auth       required   pam_wheel.so use_uid group=sudo' \
       "$TARGET/etc/pam.d/su"

# Default umask 027 (read by pam_umask). trixie's login.defs has no UMASK.
if grep -qE '^UMASK[[:space:]]' "$TARGET/etc/login.defs"; then
  sed -i -E 's/^UMASK[[:space:]]+.*/UMASK\t\t027/' "$TARGET/etc/login.defs"
else
  printf '\n# CIS: default umask (read by pam_umask)\nUMASK\t\t027\n' >> "$TARGET/etc/login.defs"
fi

# --- sudo ---------------------------------------------------------------------
chmod 0440 "$TARGET/etc/sudoers.d/50-cis"
in_chroot visudo -c -q
install -o root -g root -m 0600 /dev/null "$TARGET/var/log/sudo.log"

# --- cron: root only (others: sudo crontab) -----------------------------------
chmod 0600 "$TARGET/etc/crontab"
chmod 0700 "$TARGET"/etc/cron.{hourly,daily,weekly,monthly,d}
# cron.allow is read by the setgid crontab program, hence group crontab
# (looked up inside the image).
in_chroot chown root:crontab /etc/cron.allow
chmod 0640 "$TARGET/etc/cron.allow"
rm -f "$TARGET/etc/cron.deny"

# --- journald: audit records only in auditd's log ------------------------------
in_chroot systemctl mask systemd-journald-audit.socket
