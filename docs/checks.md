# Build checks

What the build verifies in the finished image before it is packaged:
`os/debian/steps/80-checks.sh` (plus a VMware section) runs these
checks inside the build, and **any failed check stops the build**, so
an OVA is only produced when all of them hold. The checks look at the
image files and, where it matters, the effective configuration (e.g.
`sshd -T`, `nft -c`, `aide --config-check`, `systemctl is-enabled`).

Debian 13 for VMware has **271 checks**; the Docker template
(`debian-13-docker`) has **292** (the base checks except "nothing
forwarded", plus the [role checks](#role-docker)). Sizes below are the defaults
(`DISK_GB=50`, `SWAP_GB=2`, `ESP_MIB=512`); the checks use the build
settings. When a check is added to `80-checks.sh`, add it here too.

| Section | Checks |
|---|---|
| [Disk layout](#disk-layout) | 39 |
| [Boot](#boot) | 8 |
| [System and network](#system-and-network) | 15 |
| [CIS hardening](#cis-hardening) | 53 |
| [auditd](#auditd) | 28 |
| [AIDE](#aide) | 14 |
| [Logs and monitoring](#logs-and-monitoring) | 12 |
| [SSH](#ssh) | 21 |
| [Firewall and fail2ban](#firewall-and-fail2ban) | 18 |
| [Banners and MOTD](#banners-and-motd) | 12 |
| [Platform: VMware](#platform-vmware) | 15 |
| [Common packages and tools](#common-packages-and-tools) | 34 |
| [Roles](#roles) | 1 (base) / 22 (docker) |
| [Updates](#updates) | 1 |

## Disk layout

See [`disk-layout.md`](disk-layout.md).

- For each of the 9 subvolumes (`@root`, `@home`, `@var`, `@log`,
  `@log-audit`, `@log-archives`, `@tmp`, `@var-tmp`, `@snapshots`),
  3 checks each (27):
  - the subvolume exists
  - its mount point is mounted from it
  - `/etc/fstab` has it, by UUID and with its mount options
- subvolume count = 9
- `/tmp` and `/var/tmp` are 1777 (2)
- fstab: `/dev/shm` tmpfs with `nodev,nosuid,noexec`
- fstab: swap disk by UUID with `sw,nofail,x-systemd.device-timeout=10s`
- disk 1 has 2 partitions (ESP, Btrfs)
- disk 1: ESP is 512 MiB
- disk 1: Btrfs is the last partition (it can grow)
- disk 2: 2 GiB swap, label `swap`
- `swap-grow.service` enabled
- initramfs config `RESUME=none` (no hibernation)
- fstab: ESP by UUID, `umask=0077`

## Boot

- removable EFI loader `/EFI/BOOT/BOOTX64.EFI`
- kernel installed
- initramfs installed
- `grub.cfg`: `root=UUID=<btrfs>`
- `grub.cfg`: `rootflags=subvol=@root`
- `grub.cfg`: no loop or device-mapper paths from the build
- initramfs contains the Btrfs module
- initramfs carries the `RESUME=none` config

## System and network

See [`network.md`](network.md).

- hostname `debian-13-template` (replaced per VM at first boot)
- apt sources in deb822 format, no legacy `sources.list` (2)
- `systemd-timesyncd` enabled
- `networking.service` enabled; `/etc/network/interfaces` sources
  `interfaces.d` (2)
- `dhcpcd` installed, with `ipv4only` (2)
- `systemd-networkd` service, socket and wait-online disabled (3)
- not installed: `systemd-resolved`, `resolvconf`, `network-manager`,
  `netplan.io` (4)

## CIS hardening

See [`hardening.md`](hardening.md).

- sysctl: unprivileged ping (`ping_group_range`)
- sysctl: IPv6 disabled (all, default, lo)
- sysctl values (8): `net.ipv4.ip_forward = 0`,
  `net.ipv4.conf.all.accept_redirects = 0`,
  `net.ipv4.conf.all.send_redirects = 0`,
  `net.ipv4.conf.all.rp_filter = 1`,
  `net.ipv4.conf.all.log_martians = 1`, `net.ipv4.tcp_syncookies = 1`,
  `fs.suid_dumpable = 0`, `kernel.yama.ptrace_scope = 1`
- kernel modules blocked (8): `cramfs`, `freevxfs`, `hfs`, `hfsplus`,
  `jffs2`, `squashfs`, `udf`, `usb-storage`
- core dumps off (limits)
- cron: `/etc/crontab` 0600; `cron.hourly`, `cron.daily`, `cron.weekly`,
  `cron.monthly`, `cron.d` 0700 (6)
- cron: `cron.allow` root:crontab 0640 with only root; no `cron.deny` (2)
- pwquality: `minlen 14`, `minclass 4`; cracklib dictionary present (2)
- PAM: pwquality, pwhistory `remember=24`, faillock preauth, authfail
  and account (5)
- faillock: `deny 5`, `unlock 900`
- `su` only for group `sudo`
- umask 027: `login.defs`, PAM session, PAM non-interactive (3)
- sudo: sudoers valid, `sudoers.d/50-cis` 0440, logfile + `use_pty` +
  timeout 60, `/var/log/sudo.log` 0600 (4)
- `TMOUT=3600`, read-only
- AppArmor installed, `apparmor.service` enabled (2)
- journald: `Audit=no`, journald audit socket masked (2)
- GRUB: CIS kernel options, entries `--unrestricted`, `grub.cfg` 0600 (3)
- GRUB: `grub-mkpasswd-pbkdf2` present; no GRUB password in the image
  (set per VM) (2)

## auditd

See [`auditing.md`](auditing.md).

- no Debian `audit.rules` (would run `-D` after the lock)
- `rules.d/` files 0640 (6): `10-base`, `20-exclude`, `30-cis`,
  `31-privileged`, `50-template`, `99-finalize`
- privileged-command rules generated
- rules locked last (`-e 2`)
- no access / delete rules (documented deviation)
- every watched folder exists (a missing one stops the rule load)
- `/root/.ssh` 0700
- `auditd.conf` (9): `log_group = root`, `max_log_file = 200`,
  `max_log_file_action = keep_logs`, `space_left = 15%`,
  `space_left_action = exec /usr/local/sbin/audit-space-warn`,
  `admin_space_left = 3%`, `admin_space_left_action = halt`,
  `disk_full_action = halt`, `disk_error_action = halt`
- `auditd.service` and `audit-archive.timer` enabled (2)
- `audit-archive` and `audit-space-warn`: 0750 and shell syntax ok (4)
- `zstd` installed (audit archive)

## AIDE

See [`integrity.md`](integrity.md).

- AIDE config valid
- scope: the essential list, no whole-filesystem rule
- audit tools watched (CIS)
- `COPYNEWDB=ifnochange`
- disk device nodes (`/dev/sdX…`) and `/dev/disk/` links not watched
  (their names follow the disk discovery order, which can change between
  boots)
- no mail
- no baseline in the image (created per VM)
- `aide-accept`: 0750 and shell syntax ok (2)
- apt hook runs `aide-accept --after-apt`
- `aide-firstboot.timer`, `dailyaidecheck.timer` enabled (2)
- `dm_mod` loaded at boot
- audit watch on the AIDE config

## Logs and monitoring

See [`logs.md`](logs.md).

- sudo log rotation: config valid; daily, 40 days, `create 0600` (2)
- `logrotate.timer` enabled
- sysstat enabled; `sysstat.service`, `sysstat-collect`, `-summary`,
  `-rotate` timers enabled (5)
- `/var/log/sysstat` exists
- sysstat: not audited, excluded from AIDE (2)
- `growpart` installed (disk growth)

## SSH

See [`ssh.md`](ssh.md). Checked on the effective config (`sshd -T`).

- 13 settings: `port 10022`, `banner /etc/issue.net`,
  `permitrootlogin no`, `passwordauthentication no`,
  `kbdinteractiveauthentication no`, `maxauthtries 4`,
  `logingracetime 60`, `maxstartups 10:30:60`,
  `clientaliveinterval 300`, `clientalivecountmax 3`,
  `disableforwarding yes`, `allowgroups sudo`, `allowgroups ssh`
- no CBC cipher; no SHA-1 / UMAC / MD5 MAC; no SHA-1 key exchange (3)
- sshd config files 0600
- group `ssh` exists
- `ssh.service` enabled, `ssh.socket` disabled (2)
- `ssh.service` creates host keys before it starts

## Firewall and fail2ban

See [`firewall.md`](firewall.md).

- `nftables.conf` valid (`nft -c`)
- own table, no `flush ruleset`
- input policy drop
- `SSH_PORT` 10022, the same as sshd
- `nftables.d/` files 0644 (7): `std-define`, `std-sets`, `std-input`,
  `std-forward`, `custom-define`, `custom-sets`, `custom-input`
- `nftables.service` enabled
- fail2ban config valid
- fail2ban `sshd` jail: port 10022, mode aggressive, systemd backend
- `fail2ban.service` enabled and requires nftables (2)
- `python3-systemd` installed (fail2ban reads the journal)
- `firewalld` not installed

## Banners and MOTD

See [`ssh.md`](ssh.md).

- `/etc/issue` and `/etc/issue.net` (6): 0644, authorized-use warning,
  no OS details (`\m \r \s \v`)
- `/etc/motd` empty, `/etc/update-motd.d` empty (2)
- `zn-motd`: 0755, shell syntax ok, linked as the MOTD (3)
- `wget` installed (used by zn-motd)

## Platform: VMware

See [`platforms/vmware.md`](platforms/vmware.md) and
[`first-boot.md`](first-boot.md).

- `vmware-rpctool` installed
- `cloud-init` installed
- `vapp-seed`: executable, compiles (2)
- `aide-vapp-accept.timer`, `vapp-seed-recheck.timer` enabled (2)
- audit rules load after `vapp-seed`
- `vapp-seed.service` enabled
- cloud-init datasource `NoCloud`; `ds-identify` policy enabled (2)
- `vapp-seed` defaults match the build settings (domain, user, time
  zone)
- the default time zone exists
- installed: `growpart`, `sudo`, `ssh-keygen` (host keys) (3)

## Common packages and tools

See [`packages.md`](packages.md).

- every package in `common/packages.list` installed (32)
- `witr` in `/usr/local/bin`: 0755, runs
- `durank` in `/usr/local/bin`: 0755, shell syntax ok

## Roles

Each role's `roles/<role>/<os>/checks.sh`.

**No role (base):** nothing forwarded (`std-forward.nft` has no rules).

### Role docker

See [`roles/docker.md`](roles/docker.md).

- Docker key `/etc/apt/keyrings/docker.asc` 0644; apt source
  `download.docker.com`, signed by that key (2)
- installed (7): `docker-ce`, `docker-ce-cli`, `containerd.io`,
  `docker-buildx-plugin`, `docker-compose-plugin`, `ca-certificates`,
  `curl`
- enabled (3): `containerd.service`, `docker.service`, `docker.socket`
- group `docker` exists
- `daemon.json` valid with `json-file` logs, `live-restore`,
  `no-new-privileges`, no userland proxy, `icc` off
- sysctl `ip_forward = 1` (CIS deviation)
- nftables forwards `docker0` and `br-*` (4 rules); `nftables.conf`
  still valid (2)
- container logs kept 14 days (logrotate config valid)
- audit rules `60-docker.rules` 0640
- AIDE watches `/etc/docker`; AIDE config valid with the role rules (2)
- the admin joins `docker` (`vapp-seed` group list)

## Updates

- nothing left to upgrade (the image has the latest packages)
