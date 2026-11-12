# Debian

## Debian 13 (trixie)

| Item | Value |
|---|---|
| Installed with | `debootstrap` (minbase), then the latest point release and security updates (`apt full-upgrade`) |
| Mirrors | `deb.debian.org` (`trixie`, `trixie-updates`, `trixie-security`), deb822 format (`/etc/apt/sources.list.d/debian.sources`) |
| Packages | `common/packages.list` + `os/debian/13/packages.list` + the platform's list, without recommends ([`packages.md`](../packages.md)) |
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

The full list with the purpose of each package is in
[`packages.md`](../packages.md): the common tools (`common/packages.list`,
e.g. SSH, nftables, fail2ban, auditd, AIDE, curl, rsync, vim, jq,
Python), the Debian-specific ones (`os/debian/13/packages.list`, e.g.
AppArmor, PAM pwquality), VMware's `open-vm-tools` and `cloud-init`, and
`witr` / `durank` downloaded to `/usr/local/bin`.
