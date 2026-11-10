# Auditing (auditd)

auditd records security-relevant changes and actions in
`/var/log/audit/audit.log`. The rules follow the CIS Debian benchmark,
plus watches on the files that matter most for an investigation.

## What is recorded

Search by key: `sudo ausearch -i -k <key>`.

| Key | What |
|---|---|
| `identity` | accounts and groups (`passwd`, `shadow`, `group`, …), `nsswitch.conf`, PAM |
| `scope` | sudoers |
| `sudo_log_file` | sudo's own log written |
| `user_emulation` | commands run as another user by a logged-in user |
| `privileged` | any setuid/setgid program run by a logged-in user |
| `perm_mod` | `chmod`, `chown`, extended attributes, by logged-in users |
| `perm_chng`, `usermod` | `chcon`, `setfacl`, `chacl`, `usermod` run by logged-in users |
| `mounts` | file systems mounted by logged-in users |
| `time-change` | system clock or time zone changed |
| `system-locale` | host name, `/etc/hosts`, network configuration, login banners |
| `session`, `logins` | login records |
| `MAC-policy` | AppArmor configuration |
| `kernel_modules` | kernel modules loaded or removed |
| `startup` | `/boot`, systemd units, init scripts, module loading, cron |
| `audit-config` | audit configuration, `/etc/default/grub` |
| `sshd` | `/etc/ssh` |
| `ssh-keys` | `/root/.ssh` and the admin's `~/.ssh` |
| `auth` | PAM, `/etc/security`, `login.defs` |
| `preload` | library preloading (`ld.so.preload`, `ld.so.conf`) |
| `shell-startup` | system and root / admin shell start-up files |
| `nftables` | firewall rules changed, `nft` run by a logged-in user |
| `fail2ban` | fail2ban configuration, `fail2ban-client` run by a logged-in user |

"Logged-in user" means a person who logged in (also through `sudo`),
not a service.

Not recorded, to keep the log readable (deviations from CIS): failed
file access and file deletion by users. Applications (databases,
containers, …) are not audited; add your own rules for them.

The admin's rules (`/etc/audit/rules.d/55-admin.rules`) are written at
boot for the account from the VM properties. On first boot the account
is created after the rules are loaded, so the VM reboots once by itself
to load them.

## Rules are locked

The rules are locked at boot (`-e 2`): they can't be changed or switched
off until the next reboot, also not by root. To add rules, put a file in
`/etc/audit/rules.d/` (sorted before `99-finalize.rules`, e.g.
`60-myapp.rules`) and reboot. Check the result with `sudo auditctl -l`
and `sudo auditctl -s` (`enabled 2`, `lost 0`).

A rule on a folder that doesn't exist stops the whole rule load (no
auditing at all): create the folder first.

## Disk space

The audit log is on the same disk as everything else (a Btrfs
subvolume), so the limits are about the **whole disk**:

| Free space | Action |
|---|---|
| below 15% | warning in the journal and on all terminals |
| below 3% | **the VM halts** |

Keep large data (databases, indexes) on a separate virtual disk.

## Log archive

Every day at 00:00 (UTC) the log is rotated and compressed into
`/var/log/archives/audit/audit-<date>.log.zst`. Archives are kept for 40
days. auditd itself never deletes logs; at 200 MB it starts a new file,
which the next archive run picks up.

```sh
sudo ausearch -i -k identity                       # current log
sudo zstdcat /var/log/archives/audit/audit-2026-11-09.log.zst | sudo ausearch -i -k identity
```

In scripts, use `ausearch --input-logs ...`: without a terminal,
`ausearch` reads from standard input instead of the log files.

## Known limitation

File watches match by device and inode number. All Btrfs subvolumes
(`/`, `/home`, `/var`, …) count as one device here, and inode numbers
repeat between subvolumes, so a watch can occasionally record an
unrelated path in another subvolume. The record's `name=` field shows
the real path; no changes are missed.
