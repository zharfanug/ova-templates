# File integrity (AIDE)

AIDE keeps a baseline of the files that matter for security and reports
every difference once a day.

## What is watched

| Group | Paths |
|---|---|
| Startup | `/boot`, `/etc/systemd`, `/usr/lib/systemd`, `/etc/init.d`, `/etc/rc.local`, `/etc/modules-load.d`, `/etc/modprobe.d`, cron (`/etc/crontab`, `/etc/cron.*`, `/var/spool/cron`) |
| Programs | `/usr/bin`, `/usr/sbin`, `/usr/local/bin`, `/usr/local/sbin` |
| Audit and AIDE configuration | `/etc/audit`, `/etc/default/grub`, `/etc/aide`, `/etc/default/aide`, the apt hook; audit programs with extra checksums (CIS) |
| sudo | `/etc/sudoers`, `/etc/sudoers.d` |
| SSH | `/etc/ssh`, `/root/.ssh`, every `/home/<user>/.ssh` |
| Accounts and login | `/etc/passwd`, `shadow`, `group`, `gshadow`, `/etc/pam.d`, `/etc/security` |
| Library preloading | `/etc/ld.so.preload`, `/etc/ld.so.conf`, `/etc/ld.so.conf.d` |
| Shell start-up | `/etc/profile`, `/etc/profile.d`, `/etc/bash.bashrc`, `/etc/environment`, `.bashrc` / `.profile` / `.bash_profile` / `.bash_logout` of root and every user |
| Firewall, fail2ban | `/etc/nftables.conf`, `/etc/nftables.d`, `/etc/fail2ban` |

Debian's own AIDE snippets add a few specific files elsewhere.

**Not watched:** libraries (`/usr/lib` outside systemd), `/opt`, the
rest of `/etc` and `/var`, application data, `known_hosts`, LVM's
runtime state (`/run/lvm`, created when a data disk uses LVM). Data that
changes by design would only produce noise.

Configuration: `/etc/aide/aide.conf.d/99_aide_root`.

## Baseline

The image has no baseline: each VM builds its own **5 minutes after its
first boot** (`aide-firstboot.timer`), and again after a machine
identity reset (new `vm_uuid`, see [`first-boot.md`](first-boot.md)).

## Daily check

`dailyaidecheck.timer` compares the files with the baseline every day:

- full report: `/var/log/aide/aide.log` (last 7 runs kept);
- one summary line in the journal: `journalctl -t dailyaidecheck`.

There is no mail. The baseline is only replaced after a check found no
differences, so a difference stays in every report until it is
accepted.

## Accepting changes

| When | How |
|---|---|
| after `apt` installs, upgrades or removes packages | automatic (apt hook) |
| after a change of `vm_username`, `vm_password` or `vm_ssh_key` | automatic, 5 minutes after the boot that applied it |
| anything else (configuration edits, files added by hand) | after reviewing the report: `sudo aide-accept` |
| after adding or removing virtual hardware (a disk, the swap disk, a CD drive) | `/dev` entries change (e.g. `/dev/sg*`, `/dev/block`); after reviewing: `sudo aide-accept` |

Every accept first saves what differed to
`/var/log/aide/aide-{apt,vapp,manual}-<date>.log` (kept 40 days), so
nothing is accepted without a record. A change made just before an apt
run is accepted together with it; it is in that run's saved report.

```sh
sudo less /var/log/aide/aide.log     # latest daily report
sudo aide-accept                     # accept the current state
```
