# OVA Templates

Hardened virtual machine templates packaged as OVA files, built from
scratch with plain scripts (no installer, no ovftool).

## Templates

| Template | Platforms | OVA |
|---|---|---|
| `debian-13-amd64-efi` | vmware | `zn-debian-13-amd64-efi-vmware.ova` |

Planned: Proxmox VE platform, Docker and Wazuh manager roles, NixOS.

What a deployed VM gets:

- Debian 13 on Btrfs subvolumes with CIS mount options; the disk grows
  with the virtual disk.
- Configured from VM properties at deploy time: host name, domain, time
  zone, admin account, password, SSH keys, machine identity.
- SSH on port 10022, keys only; firewall (nftables) and fail2ban.
- CIS hardening: kernel and network settings, password rules, lockout,
  sudo logging, umask 027, AppArmor, GRUB password.
- auditd with locked CIS rules, AIDE file integrity checks, sysstat
  history, log rotation.

## Building

Requirements: Linux host with Docker (the builder runs in a privileged
container because it needs loop devices, `mount` and `chroot`).

```sh
cp .env.example .env        # optional: branding and defaults
scripts/build.sh debian-13-amd64-efi vmware
```

Output goes to `build/<ID>/`, logs to `logs/<ID>/`, where `<ID>` is the
build start time (`YYYYMMDDhhmm`).

## Documentation

| Topic | |
|---|---|
| Building, settings | [`docs/building.md`](docs/building.md) |
| File and product names | [`docs/naming.md`](docs/naming.md) |
| Adding templates, roles, platforms | [`docs/adding-a-template.md`](docs/adding-a-template.md) |
| Importing into vCenter / ESXi, VM properties | [`docs/platforms/vmware.md`](docs/platforms/vmware.md) |
| First boot, changing properties later | [`docs/first-boot.md`](docs/first-boot.md) |
| Debian specifics | [`docs/os/debian.md`](docs/os/debian.md) |
| Disk layout, growing, adding disks | [`docs/disk-layout.md`](docs/disk-layout.md) |
| Networking | [`docs/network.md`](docs/network.md) |
| SSH, login banners | [`docs/ssh.md`](docs/ssh.md) |
| Firewall, fail2ban | [`docs/firewall.md`](docs/firewall.md) |
| Hardening (CIS) | [`docs/hardening.md`](docs/hardening.md) |
| Auditing (auditd) | [`docs/auditing.md`](docs/auditing.md) |
| File integrity (AIDE) | [`docs/integrity.md`](docs/integrity.md) |
| Logs, performance history | [`docs/logs.md`](docs/logs.md) |

## License

[GNU AGPL-3.0](LICENSE)
