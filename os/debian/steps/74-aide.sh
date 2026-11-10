#!/usr/bin/env bash
# AIDE: scope and audit-tool rules from the rootfs overlay
# (etc/aide/aide.conf.d/), daily check without mail, baseline per VM at
# first boot (aide-firstboot.timer), apt hook + aide-accept.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# Daily check: report in /var/log/aide/aide.log + journal summary. No
# mail program in the image: the mail step reads and discards the report.
# The baseline is only replaced after a clean check (ifnochange).
sed -i -E 's/^COPYNEWDB=.*/COPYNEWDB=ifnochange/' "$TARGET/etc/default/aide"
grep -q '^MAILCMD=' "$TARGET/etc/default/aide" \
  || printf "\n# Reports in /var/log/aide/aide.log + journal only; no mail program in\n# the image, so the mail step reads and discards the report.\nMAILCMD='sh -c \"cat >/dev/null\"'\n" \
     >> "$TARGET/etc/default/aide"

chmod 0750 "$TARGET/usr/local/sbin/aide-accept"
in_chroot aide --config /etc/aide/aide.conf --config-check

# apt-listchanges (if installed) builds its database once from a timer
# that then disables itself - after the baseline, so the removed timer
# link would be reported every day. Done here instead.
if [ -e "$TARGET/var/lib/dpkg/info/apt-listchanges.list" ]; then
  in_chroot python3 -m apt_listchanges.populate_database --profile apt
  in_chroot systemctl disable apt-listchanges.timer
fi

# The baseline is made per VM.
rm -f "$TARGET/var/lib/aide/aide.db" "$TARGET/var/lib/aide/aide.db.new"
in_chroot systemctl enable aide-firstboot.timer dailyaidecheck.timer
