# Hardening

The image follows the CIS Debian benchmark where it doesn't get in the way
of day-to-day administration. Deviations are listed.

| Area | Setting | File | Deviation from CIS |
|---|---|---|---|
| Network | no IP forwarding, ICMP redirects and source routing off, reverse-path filter, martians logged, SYN cookies; IPv6 off ([`network.md`](network.md)) | `/etc/sysctl.d/60-cis.conf` | |
| ptrace | users can only trace their own child processes | `/etc/sysctl.d/60-cis.conf` | |
| Core dumps | off | `/etc/security/limits.d/50-coredump.conf`, `fs.suid_dumpable` | |
| Kernel modules | `cramfs freevxfs hfs hfsplus jffs2 squashfs udf usb-storage` can't be loaded | `/etc/modprobe.d/60-cis-blacklist.conf` | |
| cron | only root may use `crontab` (others: `sudo crontab`); cron files root only | `/etc/cron.allow` | |
| Passwords | at least 14 characters, all 4 classes, no more than 3 repeated or sequential characters, no dictionary words; the last 24 can't be reused | `/etc/security/pwquality.conf.d/50-cis.conf`, PAM | no expiry |
| Lockout | 5 failed password logins lock the account for 15 minutes | `/etc/security/faillock.conf` | |
| `su` | only members of `sudo` | `/etc/pam.d/su` | CIS wants a dedicated empty group |
| sudo | logged to `/var/log/sudo.log`, runs in a pseudo-terminal, asks again after 60 minutes | `/etc/sudoers.d/50-cis` | CIS wants ≤ 15 minutes |
| Idle shells | logged out after 60 minutes (`TMOUT`, read-only) | `/etc/profile.d/50-tmout.sh` | CIS wants ≤ 15 minutes |
| umask | 027 for every login and root session (below) | `/etc/login.defs`, PAM | |
| Kernel | auditing from boot, AppArmor | `/etc/default/grub.d/60-cis.cfg` | |
| AppArmor | Debian's profiles in their default modes | | enforcement not forced |
| GRUB | password for editing boot entries and the GRUB console (below) | `/etc/grub.d/01_password` | |
| journald | audit records not copied into the journal | `/etc/systemd/journald.conf.d/50-no-audit.conf` | |

Password rules apply when a password is changed inside the VM (`passwd`).
The `vm_password` property is not checked. The lockout applies to
password logins only (console, `sudo`, `su`); SSH uses keys. To unlock an
account early:

```sh
sudo faillock --user <user> --reset
```

## umask 027

Files and directories created in a login or root session (`sudo`,
`sudo -i`) are not readable by other users: new files get 640, new
directories 750. Services keep the systemd default 022, and package
files keep their modes.

This can surprise when root creates something meant to be shared:

- apt keys copied into `/etc/apt/keyrings/` are ignored (`_apt` can't
  read them);
- software installed by hand into `/usr/local` or `/opt` gives other
  users "Permission denied";
- configuration created for a service that runs as its own user is
  unreadable to it.

Set the mode explicitly in those cases: `sudo install -m 0644 <src>
<dest>`, `chmod 644`, or `umask 022` at the top of a deployment script.

## GRUB password

Booting needs no password. Editing a boot entry or opening the GRUB
console asks for user `root` and a password: the last 12 characters of
the VM's `vm_uuid` property ([`first-boot.md`](first-boot.md)). It is set
at first boot and again whenever `vm_uuid` changes. Anyone who can read
the VM's properties can read it.
