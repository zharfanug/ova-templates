#!/usr/bin/env bash
# Build checks: fail the build when an expected result is missing.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
load_devs

btrfs_uuid=$(blkid -s UUID -o value "$BTRFS_DEV")
grub_cfg="$TARGET/boot/grub/grub.cfg"

# --- disk layout ------------------------------------------------------------
for entry in "${SUBVOLS[@]}"; do
  read -r name path extra <<< "$entry"
  need "subvolume $name exists" btrfs subvolume show "$TARGET$path"
  need "$path mounted from $name" \
    sh -c "findmnt -n -o OPTIONS '$TARGET$path' | grep -q 'subvol=/$name\(,\|\$\)'"
  need "fstab: $path -> $name" \
    grep -Eq "^UUID=$btrfs_uuid $path btrfs $(subvol_opts "$name" "$path" "${extra:-}") 0 0\$" "$TARGET/etc/fstab"
done
need "subvolume count = ${#SUBVOLS[@]}" \
  test "$(btrfs subvolume list "$TARGET" | wc -l)" -eq "${#SUBVOLS[@]}"
for d in "${STICKY_DIRS[@]}"; do
  need "$d is 1777" test "$(stat -c %a "$TARGET$d")" = 1777
done
need "fstab: /dev/shm nodev,nosuid,noexec" \
  grep -Eq '^tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec ' "$TARGET/etc/fstab"
swap_uuid=$(blkid -s UUID -o value "$SWAP_DEV")
need "fstab: swap disk by UUID, nofail" \
  grep -Eq "^UUID=$swap_uuid none swap $SWAP_OPTS 0 0\$" "$TARGET/etc/fstab"
need "disk 1: 2 partitions (ESP, Btrfs)" \
  test "$(parted -s -m "$IMAGE" print | grep -c '^[0-9]:')" -eq 2
need "disk 1: ESP ${ESP_MIB} MiB" test "$(blockdev --getsize64 "$ESP_DEV")" -eq $((ESP_MIB * 1024 * 1024))
need "disk 1: Btrfs is the last partition" test "$BTRFS_DEV" = "${LOOP}p2"
need "disk 2: ${SWAP_GB} GiB swap, label swap" \
  sh -c "[ \$(blockdev --getsize64 '$SWAP_DEV') -eq $((SWAP_GB * 1024 * 1024 * 1024)) ] && [ \"\$(blkid -o value -s LABEL '$SWAP_DEV')\" = swap ]"
need "swap-grow enabled" test "$(in_chroot systemctl is-enabled swap-grow.service 2>/dev/null)" = enabled
need "initramfs: RESUME=none" grep -qx 'RESUME=none' "$TARGET/etc/initramfs-tools/conf.d/resume"
need "fstab: ESP by UUID" grep -Eq '^UUID=\S+ /boot/efi vfat umask=0077 ' "$TARGET/etc/fstab"

# --- boot -------------------------------------------------------------------
need "removable EFI loader" test -f "$TARGET/boot/efi/EFI/BOOT/BOOTX64.EFI"
need "kernel installed" sh -c "ls '$TARGET'/boot/vmlinuz-*"
need "initramfs installed" sh -c "ls '$TARGET'/boot/initrd.img-*"
need "grub.cfg: root=UUID=<btrfs>" grep -Eq "^\s*linux\s.*root=UUID=$btrfs_uuid( |\$)" "$grub_cfg"
need "grub.cfg: rootflags=subvol=@root" grep -Eq '^\s*linux\s.*rootflags=subvol=@root( |$)' "$grub_cfg"
need "grub.cfg: no loop / mapper devices" sh -c "! grep -Eq '/dev/(loop|mapper)' '$grub_cfg'"
need "initramfs has btrfs" \
  in_chroot sh -c 'lsinitramfs /boot/initrd.img-* | grep -Eq "/btrfs\.ko(\.[a-z]+)?$"'
need "initramfs: carries RESUME=none" \
  in_chroot sh -c 'lsinitramfs /boot/initrd.img-* | grep -qx "conf/conf.d/resume"'

# --- system -----------------------------------------------------------------
need "hostname $IMAGE_HOSTNAME" test "$(cat "$TARGET/etc/hostname")" = "$IMAGE_HOSTNAME"
need "deb822 apt sources" test -f "$TARGET/etc/apt/sources.list.d/debian.sources"
need "no legacy sources.list" test ! -e "$TARGET/etc/apt/sources.list"
need "systemd-timesyncd enabled (time sync)" test "$(in_chroot systemctl is-enabled systemd-timesyncd.service 2>/dev/null)" = enabled
need "networking.service enabled" \
  test -L "$TARGET/etc/systemd/system/multi-user.target.wants/networking.service"
need "/etc/network/interfaces sources interfaces.d" \
  grep -q '^source /etc/network/interfaces.d/\*' "$TARGET/etc/network/interfaces"
need "dhcpcd installed" test -x "$TARGET/usr/sbin/dhcpcd"
need "dhcpcd: ipv4only" grep -qx ipv4only "$TARGET/etc/dhcpcd.conf"
for u in systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service; do
  need "$u disabled" test "$(in_chroot systemctl is-enabled "$u" 2>/dev/null)" = disabled
done
for pkg in systemd-resolved resolvconf network-manager netplan.io; do
  need "$pkg not installed" test ! -e "$TARGET/var/lib/dpkg/info/$pkg.list"
done
need "sysctl: unprivileged ping (ping_group_range)" \
  grep -rqE '^-?net\.ipv4\.ping_group_range\s*=\s*0\s+2147483647' "$TARGET/usr/lib/sysctl.d"
need "sysctl: IPv6 disabled (all, default, lo)" \
  test "$(grep -cE '^net\.ipv6\.conf\.(all|default|lo)\.disable_ipv6 = 1$' "$TARGET/etc/sysctl.d/60-cis.conf")" -eq 3

# --- CIS hardening ----------------------------------------------------------
for kv in "net.ipv4.ip_forward = 0" "net.ipv4.conf.all.accept_redirects = 0" \
    "net.ipv4.conf.all.send_redirects = 0" "net.ipv4.conf.all.rp_filter = 1" \
    "net.ipv4.conf.all.log_martians = 1" "net.ipv4.tcp_syncookies = 1" \
    "fs.suid_dumpable = 0" "kernel.yama.ptrace_scope = 1"; do
  need "sysctl: $kv" grep -qx "$kv" "$TARGET/etc/sysctl.d/60-cis.conf"
done
for m in cramfs freevxfs hfs hfsplus jffs2 squashfs udf usb-storage; do
  need "modprobe: $m blocked" grep -qx "install $m /bin/false" "$TARGET/etc/modprobe.d/60-cis-blacklist.conf"
done
need "core dumps off (limits)" grep -qx '\* hard core 0' "$TARGET/etc/security/limits.d/50-coredump.conf"
need "/etc/crontab 0600" test "$(stat -c %a "$TARGET/etc/crontab")" = 600
for d in hourly daily weekly monthly d; do
  need "/etc/cron.$d 0700" test "$(stat -c %a "$TARGET/etc/cron.$d")" = 700
done
need "cron.allow root:crontab 0640, only root" \
  test "$(in_chroot stat -c '%U:%G %a' /etc/cron.allow):$(cat "$TARGET/etc/cron.allow")" = "root:crontab 640:root"
need "no cron.deny" test ! -e "$TARGET/etc/cron.deny"
need "pwquality: minlen 14, minclass 4" \
  sh -c "grep -qx 'minlen = 14' '$TARGET/etc/security/pwquality.conf.d/50-cis.conf' && grep -qx 'minclass = 4' '$TARGET/etc/security/pwquality.conf.d/50-cis.conf'"
need "cracklib dictionary (dictcheck)" test -s "$TARGET/var/cache/cracklib/cracklib_dict.pwd"
need "PAM: pwquality" grep -q 'pam_pwquality.so' "$TARGET/etc/pam.d/common-password"
need "PAM: pwhistory remember=24" grep -q 'pam_pwhistory.so remember=24' "$TARGET/etc/pam.d/common-password"
need "PAM: faillock preauth" grep -q 'pam_faillock.so preauth' "$TARGET/etc/pam.d/common-auth"
need "PAM: faillock authfail" grep -q 'pam_faillock.so authfail' "$TARGET/etc/pam.d/common-auth"
need "PAM: faillock account" grep -q 'pam_faillock.so' "$TARGET/etc/pam.d/common-account"
need "faillock: deny 5, unlock 900" \
  sh -c "grep -qx 'deny = 5' '$TARGET/etc/security/faillock.conf' && grep -qx 'unlock_time = 900' '$TARGET/etc/security/faillock.conf'"
need "su: only group sudo" grep -q '^auth *required *pam_wheel.so use_uid group=sudo' "$TARGET/etc/pam.d/su"
need "login.defs: UMASK 027" grep -qE '^UMASK[[:space:]]+027$' "$TARGET/etc/login.defs"
need "PAM: umask 027 (session)" grep -q 'pam_umask.so umask=0027 nousergroups' "$TARGET/etc/pam.d/common-session"
need "PAM: umask 027 (noninteractive)" grep -q 'pam_umask.so umask=0027 nousergroups' "$TARGET/etc/pam.d/common-session-noninteractive"
need "sudoers valid" in_chroot visudo -c -q
need "sudoers.d/50-cis 0440" test "$(stat -c %a "$TARGET/etc/sudoers.d/50-cis")" = 440
need "sudo: logfile, use_pty, timeout 60" \
  sh -c "grep -qx 'Defaults logfile=\"/var/log/sudo.log\"' '$TARGET/etc/sudoers.d/50-cis' && grep -qx 'Defaults use_pty' '$TARGET/etc/sudoers.d/50-cis' && grep -qx 'Defaults timestamp_timeout=60' '$TARGET/etc/sudoers.d/50-cis'"
need "/var/log/sudo.log 0600" test "$(stat -c %a "$TARGET/var/log/sudo.log")" = 600
need "TMOUT=3600 readonly" \
  sh -c "grep -qx 'TMOUT=3600' '$TARGET/etc/profile.d/50-tmout.sh' && grep -qx 'readonly TMOUT' '$TARGET/etc/profile.d/50-tmout.sh'"
need "AppArmor installed" test -x "$TARGET/usr/sbin/apparmor_parser"
need "apparmor.service enabled" test "$(in_chroot systemctl is-enabled apparmor.service 2>/dev/null)" = enabled
need "journald: Audit=no" grep -qx 'Audit=no' "$TARGET/etc/systemd/journald.conf.d/50-no-audit.conf"
need "journald audit socket masked" test "$(in_chroot systemctl is-enabled systemd-journald-audit.socket 2>/dev/null)" = masked
need "grub.cfg: CIS kernel options" \
  grep -Eq '^\s*linux\s.* audit=1 audit_backlog_limit=8192 apparmor=1 security=apparmor( |$)' "$grub_cfg"
need "grub.cfg: entries --unrestricted" grep -Eq "^menuentry .*--unrestricted" "$grub_cfg"
need "grub.cfg 0600" test "$(stat -c %a "$grub_cfg")" = 600
need "grub-mkpasswd-pbkdf2 present (vapp-seed)" test -x "$TARGET/usr/bin/grub-mkpasswd-pbkdf2"
need "no GRUB password in the image (set per VM)" test ! -e "$TARGET/etc/grub.d/01_password"

# --- auditd -----------------------------------------------------------------
rules="$TARGET/etc/audit/rules.d"
need "no Debian audit.rules (would run -D after the lock)" test ! -e "$rules/audit.rules"
for f in 10-base 20-exclude 30-cis 31-privileged 50-template 99-finalize; do
  need "rules.d/$f.rules 0640" test "$(stat -c %a "$rules/$f.rules")" = 640
done
need "privileged rules generated" grep -q 'key=privileged$' "$rules/31-privileged.rules"
need "rules locked last (-e 2)" test "$(cat "$rules"/*.rules | grep -v '^#' | grep -v '^$' | tail -n1)" = "-e 2"
need "no access / delete rules (deviation)" sh -c "! grep -hE 'key=(access|delete)\$' '$rules'/*.rules | grep -q ."
# A watch on a missing folder (or a file in one) stops the whole rule load.
missing=""
while read -r kind path; do
  case "$kind" in
    dir) [ -d "$TARGET$path" ] || missing="$missing $path" ;;
    path) [ -d "$TARGET$(dirname "$path")" ] || missing="$missing $path" ;;
  esac
done < <(grep -hoE -- '-F (dir|path)=[^ ]+' "$rules"/*.rules | sed -E 's/^-F (dir|path)=/\1 /' | sort -u)
need "every watched folder exists${missing:+ (missing:$missing)}" test -z "$missing"
need "/root/.ssh 0700" test "$(stat -c %a "$TARGET/root/.ssh")" = 700
for kv in "log_group = root" "max_log_file = 200" "max_log_file_action = keep_logs" \
    "space_left = 15%" "space_left_action = exec /usr/local/sbin/audit-space-warn" \
    "admin_space_left = 3%" "admin_space_left_action = halt" \
    "disk_full_action = halt" "disk_error_action = halt"; do
  need "auditd.conf: $kv" grep -qx "$kv" "$TARGET/etc/audit/auditd.conf"
done
need "auditd.service enabled" test "$(in_chroot systemctl is-enabled auditd.service 2>/dev/null)" = enabled
need "audit-archive.timer enabled" test "$(in_chroot systemctl is-enabled audit-archive.timer 2>/dev/null)" = enabled
for f in audit-archive audit-space-warn; do
  need "$f 0750" test "$(stat -c %a "$TARGET/usr/local/sbin/$f")" = 750
  need "$f syntax" sh -n "$TARGET/usr/local/sbin/$f"
done
need "zstd installed (audit archive)" test -x "$TARGET/usr/bin/zstd"

# --- AIDE -------------------------------------------------------------------
need "AIDE config valid" in_chroot aide --config /etc/aide/aide.conf --config-check
need "AIDE scope: essential list (no whole-filesystem rule)" \
  sh -c "grep -qx '/usr/sbin Full' '$TARGET/etc/aide/aide.conf.d/99_aide_root' && ! grep -qx '/ 0 Full' '$TARGET/etc/aide/aide.conf.d/99_aide_root'"
need "AIDE: audit tools (CIS)" grep -q '^/usr/sbin/auditctl p+i+n+u+g+s+b+acl+xattrs+sha512$' "$TARGET/etc/aide/aide.conf.d/90_aide_audit_tools"
need "AIDE: COPYNEWDB=ifnochange" grep -qx 'COPYNEWDB=ifnochange' "$TARGET/etc/default/aide"
need "AIDE: disk names and /dev/disk excluded (order changes between boots)" \
  sh -c "grep -qxF '!/dev/sd[a-z]+[0-9]*\$ b' '$TARGET/etc/aide/aide.conf.d/99_aide_root' && grep -qxF '!/dev/disk(/|\$)' '$TARGET/etc/aide/aide.conf.d/99_aide_root'"
need "AIDE: no mail" grep -q '^MAILCMD=' "$TARGET/etc/default/aide"
need "AIDE: no baseline in the image" sh -c "[ ! -e '$TARGET/var/lib/aide/aide.db' ] && [ ! -e '$TARGET/var/lib/aide/aide.db.new' ]"
need "aide-accept 0750" test "$(stat -c %a "$TARGET/usr/local/sbin/aide-accept")" = 750
need "aide-accept syntax" sh -n "$TARGET/usr/local/sbin/aide-accept"
need "apt hook: aide-accept --after-apt" grep -q 'aide-accept --after-apt' "$TARGET/etc/apt/apt.conf.d/99aide-accept"
for u in aide-firstboot.timer dailyaidecheck.timer; do
  need "$u enabled" test "$(in_chroot systemctl is-enabled "$u" 2>/dev/null)" = enabled
done
need "dm_mod loaded at boot" grep -qx dm_mod "$TARGET/etc/modules-load.d/dm_mod.conf"
need "audit: aide-config watch" grep -q 'dir=/etc/aide -F perm=wa -F key=aide-config' "$TARGET/etc/audit/rules.d/50-template.rules"

# --- logs, monitoring -------------------------------------------------------
need "logrotate: sudo-log valid" in_chroot logrotate -d /etc/logrotate.d/sudo-log
need "sudo-log: daily, 40 days, create 0600" \
  sh -c "grep -qP '^\trotate 40$' '$TARGET/etc/logrotate.d/sudo-log' && grep -qP '^\tcreate 0600 root root$' '$TARGET/etc/logrotate.d/sudo-log'"
need "logrotate.timer enabled" test "$(in_chroot systemctl is-enabled logrotate.timer 2>/dev/null)" = enabled
need "sysstat enabled" grep -qx 'ENABLED="true"' "$TARGET/etc/default/sysstat"
for u in sysstat.service sysstat-collect.timer sysstat-summary.timer sysstat-rotate.timer; do
  need "$u enabled" test "$(in_chroot systemctl is-enabled "$u" 2>/dev/null)" = enabled
done
need "/var/log/sysstat exists" test -d "$TARGET/var/log/sysstat"
need "audit: sysstat not audited" grep -q 'never,exit -F arch=b64 -F dir=/var/log/sysstat' "$TARGET/etc/audit/rules.d/20-exclude.rules"
need "AIDE: sysstat excluded" grep -q '^!/var/log/sysstat' "$TARGET/etc/aide/aide.conf.d/99_aide_root"
need "growpart installed (disk growth)" test -x "$TARGET/usr/bin/growpart"

# --- ssh --------------------------------------------------------------------
# Effective sshd config, with a throwaway host key (the image has none).
# /run is a tmpfs here so nothing is left in the image.
mount -t tmpfs tmpfs "$TARGET/run"
in_chroot ssh-keygen -q -t ed25519 -N "" -f /run/sshd-check-key >/dev/null
mkdir -p "$TARGET/run/sshd"
sshd_t=$(in_chroot /usr/sbin/sshd -T -h /run/sshd-check-key -C user=root,host=check,addr=127.0.0.1) \
  || { umount "$TARGET/run"; die "need: sshd -T"; }
umount "$TARGET/run"
for kv in "port 10022" "banner /etc/issue.net" "permitrootlogin no" \
    "passwordauthentication no" "kbdinteractiveauthentication no" \
    "maxauthtries 4" "logingracetime 60" "maxstartups 10:30:60" \
    "clientaliveinterval 300" "clientalivecountmax 3" "disableforwarding yes" \
    "allowgroups sudo" "allowgroups ssh"; do
  need "sshd: $kv" grep -qx "$kv" <<< "$sshd_t"
done
need "sshd: no CBC cipher" sh -c "! grep '^ciphers ' <<'X' | grep -q cbc
$sshd_t
X"
need "sshd: no SHA-1 / UMAC / MD5 MAC" sh -c "! grep '^macs ' <<'X' | grep -Eq 'sha1|umac|md5'
$sshd_t
X"
need "sshd: no SHA-1 key exchange" sh -c "! grep '^kexalgorithms ' <<'X' | grep -q sha1
$sshd_t
X"
need "sshd config files 0600" \
  sh -c "! find '$TARGET/etc/ssh/sshd_config' '$TARGET/etc/ssh/sshd_config.d' -type f ! -perm 0600 | grep -q ."
need "group ssh" grep -q '^ssh:' "$TARGET/etc/group"
need "ssh.service enabled" test "$(in_chroot systemctl is-enabled ssh.service 2>/dev/null)" = enabled
need "ssh.socket disabled" test "$(in_chroot systemctl is-enabled ssh.socket 2>/dev/null)" = disabled
need "ssh.service: host keys before start" \
  grep -qx 'ExecStartPre=/usr/bin/ssh-keygen -A' "$TARGET/etc/systemd/system/ssh.service.d/10-hostkeys.conf"

# --- firewall, fail2ban -----------------------------------------------------
need "nftables.conf valid (nft -c)" in_chroot nft -c -f /etc/nftables.conf
need "nftables.conf: own table, no flush ruleset" \
  sh -c "grep -qx 'destroy table inet base-nft' '$TARGET/etc/nftables.conf' && ! grep -q 'flush ruleset' '$TARGET/etc/nftables.conf'"
need "nftables: input policy drop" grep -q 'type filter hook input priority 0; policy drop;' "$TARGET/etc/nftables.conf"
need "nftables: SSH_PORT 10022 (= sshd)" grep -qx 'define SSH_PORT = 10022' "$TARGET/etc/nftables.d/std-define.nft"
for f in std-define std-sets std-input custom-define custom-sets custom-input; do
  need "nftables.d/$f.nft 0644" test "$(stat -c %a "$TARGET/etc/nftables.d/$f.nft")" = 644
done
need "nftables.service enabled" test "$(in_chroot systemctl is-enabled nftables.service 2>/dev/null)" = enabled
need "fail2ban config valid" in_chroot fail2ban-client --test
need "fail2ban: sshd jail on port 10022, aggressive, systemd" \
  sh -c "grep -qx 'port = 10022' '$TARGET/etc/fail2ban/jail.d/ssh-nft.conf' && grep -qx 'mode = aggressive' '$TARGET/etc/fail2ban/jail.d/ssh-nft.conf' && grep -qx 'backend = systemd' '$TARGET/etc/fail2ban/jail.d/ssh-nft.conf'"
need "fail2ban.service enabled" test "$(in_chroot systemctl is-enabled fail2ban.service 2>/dev/null)" = enabled
need "fail2ban requires nftables" grep -qx 'Requires=nftables.service' "$TARGET/etc/systemd/system/fail2ban.service.d/nft.conf"
need "python3-systemd installed (fail2ban journal)" test -e "$TARGET/var/lib/dpkg/info/python3-systemd.list"
need "firewalld not installed" test ! -e "$TARGET/var/lib/dpkg/info/firewalld.list"

# --- banners, motd ----------------------------------------------------------
for f in issue issue.net; do
  need "/etc/$f 0644" test "$(stat -c %a "$TARGET/etc/$f")" = 644
  need "/etc/$f: authorized use warning" grep -q 'authorized use only' "$TARGET/etc/$f"
  need "/etc/$f: no OS info (\\m \\r \\s \\v)" sh -c "! grep -q '\\\\[mrsv]' '$TARGET/etc/$f'"
done
need "/etc/motd empty" test ! -s "$TARGET/etc/motd"
need "/etc/update-motd.d empty" sh -c "[ -d '$TARGET/etc/update-motd.d' ] && [ -z \"\$(ls -A '$TARGET/etc/update-motd.d')\" ]"
need "zn-motd 0755" test "$(stat -c %a "$TARGET/etc/profile.d/zn-motd.sh")" = 755
need "zn-motd syntax" sh -n "$TARGET/etc/profile.d/zn-motd.sh"
need "motd -> zn-motd" test "$(readlink "$TARGET/usr/local/bin/motd")" = /etc/profile.d/zn-motd.sh
need "wget installed (zn-motd)" test -x "$TARGET/usr/bin/wget"

# --- platform: vmware -------------------------------------------------------
if [ "$PLATFORM" = vmware ]; then
  need "vmware-rpctool installed" test -x "$TARGET/usr/bin/vmware-rpctool"
  need "cloud-init installed" test -x "$TARGET/usr/bin/cloud-init"
  need "vapp-seed executable" test -x "$TARGET/usr/local/sbin/vapp-seed"
  need "vapp-seed compiles" in_chroot python3 -c \
    'import ast,sys; ast.parse(open("/usr/local/sbin/vapp-seed").read())'
  need "aide-vapp-accept.timer enabled" \
    test "$(in_chroot systemctl is-enabled aide-vapp-accept.timer 2>/dev/null)" = enabled
  need "vapp-seed-recheck.timer enabled" \
    test "$(in_chroot systemctl is-enabled vapp-seed-recheck.timer 2>/dev/null)" = enabled
  need "audit rules load after vapp-seed" \
    grep -qx 'After=vapp-seed.service' "$TARGET/etc/systemd/system/audit-rules.service.d/50-after-vapp-seed.conf"
  need "vapp-seed.service enabled" \
    test -L "$TARGET/etc/systemd/system/sysinit.target.wants/vapp-seed.service"
  need "cloud-init datasource NoCloud" \
    grep -q '^datasource_list: \[ NoCloud, None \]' "$TARGET/etc/cloud/cloud.cfg.d/90-vapp-seed.cfg"
  need "ds-identify policy enabled" grep -q '^policy: enabled' "$TARGET/etc/cloud/ds-identify.cfg"
  need "vapp-seed defaults match the build settings" in_chroot python3 -c "
import json, sys
d = json.load(open('/etc/vapp-seed/defaults.json'))
sys.exit(d != {'vm_domain': '$DEFAULT_DOMAIN', 'vm_username': '$DEFAULT_USERNAME', 'vm_timezone': '$DEFAULT_TIMEZONE'})"
  need "default time zone $DEFAULT_TIMEZONE exists" test -f "$TARGET/usr/share/zoneinfo/$DEFAULT_TIMEZONE"
  need "growpart installed" test -x "$TARGET/usr/bin/growpart"
  need "sudo installed" test -x "$TARGET/usr/bin/sudo"
  need "ssh-keygen installed (host keys)" test -x "$TARGET/usr/bin/ssh-keygen"
fi

need "nothing left to upgrade" \
  in_chroot sh -c '! apt-get -s full-upgrade | grep -q "^Inst "'
