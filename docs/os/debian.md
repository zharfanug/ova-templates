# Debian

## Debian 13 (trixie)

| Item | Value |
|---|---|
| Installed with | `debootstrap` (minbase), then the latest point release and security updates (`apt full-upgrade`) |
| Mirrors | `deb.debian.org` (`trixie`, `trixie-updates`, `trixie-security`), deb822 format (`/etc/apt/sources.list.d/debian.sources`) |
| Packages | `os/debian/13/packages.list` + the platform's list, without recommends |
| Kernel | `linux-image-amd64` |
| Boot | GRUB for UEFI at the removable path (`EFI/BOOT/BOOTX64.EFI`): boots without firmware boot entries |
| File system | Btrfs with subvolumes ([`disk-layout.md`](../disk-layout.md)) |
| Network | ifupdown + dhcpcd, IPv4 only ([`network.md`](../network.md)) |
| Time | `systemd-timesyncd` (Debian's NTP pool) |
| Hardening | [`hardening.md`](../hardening.md), [`ssh.md`](../ssh.md), [`firewall.md`](../firewall.md), [`auditing.md`](../auditing.md), [`integrity.md`](../integrity.md) |

The image is built from the mirror on the day of the build, so every
build has the security updates of that day; builds are not
byte-for-byte reproducible.

### Updates

```sh
sudo apt update && sudo apt full-upgrade
```

After an upgrade AIDE accepts the changed files automatically
([`integrity.md`](../integrity.md)). A kernel update needs a reboot;
the login summary shows when one is pending.

### Packages beyond a minimal system

Selected on purpose (`os/debian/13/packages.list`): `openssh-server`,
`nftables`, `fail2ban`, `auditd`, `aide`, `apparmor`, `libpam-pwquality`,
`sudo`, `cron`, `logrotate`, `sysstat`, `wget`, `less`, `nano`. VMware
adds `open-vm-tools` and `cloud-init`.
