# Packages

The packages each template installs on purpose, and why. They
come from the package lists in the repository and are installed without
"recommended" packages; their dependencies are installed too (about 308
packages in the base image, 318 in the Docker image) but not listed here.
Everything is updated to the latest point release and security updates
at build time.

Packages come in two groups, so a future OS (e.g. NixOS) gets the same
tools: **Common** (every OS, by tool; the package name can differ per
distribution) and the OS's own **base** (what only that OS needs, or
needs under its own name). Platforms and roles add their own.

| Template | Package lists |
|---|---|
| `debian-13-amd64-efi` | [Common](#common-every-os) + [Debian 13 base](#debian-13-base) + [VMware platform](#vmware-platform) |
| `debian-13-docker-amd64-efi` | the same + [Docker role](#docker-role) |

When a package list changes, update this page too.

## Common (every OS)

`common/packages.list`: the tools every template has, with their Debian
package names (a second OS maps them to its own names).

| Tool | Debian package | Purpose |
|---|---|---|
| **System** | | |
| sudo | `sudo` | admin access through the `sudo` group |
| cron | `cron` | scheduled jobs, root only |
| time sync | `systemd-timesyncd` | NTP client |
| time zones | `tzdata` | time zone data for `vm_timezone` |
| CA certificates | `ca-certificates` | trusted certificates for HTTPS |
| OpenSSL | `openssl` | admin password hash, TLS tools |
| **Remote access** | | |
| SSH server | `openssh-server` | remote login ([`ssh.md`](ssh.md)) |
| SSH client | `openssh-client` | `ssh`, `scp`, `ssh-keygen` (host keys per VM) |
| **Security** | | |
| nftables | `nftables` | firewall ([`firewall.md`](firewall.md)) |
| fail2ban | `fail2ban` | bans hosts after failed SSH logins |
| auditd | `auditd` | audit log ([`auditing.md`](auditing.md)) |
| AIDE | `aide` | file integrity checks ([`integrity.md`](integrity.md)) |
| **Storage and files** | | |
| Btrfs tools | `btrfs-progs` | root file system and subvolumes |
| zstd | `zstd` | compression for the initramfs and audit archives |
| rsync | `rsync` | file copy and sync, local or over SSH |
| unzip | `unzip` | `.zip` extraction |
| **Network** | | |
| ping | `iputils-ping` | reachability test |
| curl | `curl` | HTTP client |
| wget | `wget` | HTTP client, used by zn-motd |
| dig | `bind9-dnsutils` | DNS lookups (`dig`, `nslookup`) |
| tcpdump | `tcpdump` | packet capture |
| **Logs and monitoring** | | |
| logrotate | `logrotate` | log rotation |
| sysstat | `sysstat` | performance history with `sar` ([`logs.md`](logs.md)) |
| htop | `htop` | interactive process viewer |
| lsof | `lsof` | open files and sockets per process |
| **Editors and shell tools** | | |
| less | `less` | pager |
| nano | `nano` | editor |
| vim | `vim` | editor |
| jq | `jq` | JSON processor |
| **Python** | | |
| Python 3 | `python3` | interpreter |
| pip | `python3-pip` | package installer, inside a venv (Debian blocks system-wide `pip install`; create venvs outside `/tmp`, which is `noexec`) |
| venv | `python3-venv` | virtual environments (`python3 -m venv <dir>`) |

### Downloaded at build time (not packages)

Common too; fetched from their projects when the image is built (the
build fails if a download fails).

| Tool | Installed as | Source | Purpose |
|---|---|---|---|
| zn-motd | `/etc/profile.d/zn-motd.sh`, `/usr/local/bin/motd` | [`zharfanug/zn-motd`](https://github.com/zharfanug/zn-motd) | login summary ([`ssh.md`](ssh.md)) |
| witr | `/usr/local/bin/witr` | [`pranshuparmar/witr`](https://github.com/pranshuparmar/witr), release binary `witr-linux-amd64`, checked with `SHA256SUMS` | shows why a process, port, container or file is there |
| durank | `/usr/local/bin/durank` | [`zharfanug/linux-helper`](https://github.com/zharfanug/linux-helper), `durank.sh` | disk usage under a folder, largest first |

## Debian 13 base

`os/debian/13/packages.list`: what Debian needs on top of Common, or
under Debian-specific names.

| Package | Purpose |
|---|---|
| **Boot** | |
| `linux-image-amd64` | Linux kernel |
| `grub-efi-amd64` | boot loader (UEFI) |
| `systemd-sysv` | systemd as init |
| **System** | |
| `dbus` | system message bus |
| `locales` | locales |
| **Network** | |
| `ifupdown` | network configuration (`/etc/network/interfaces`) |
| `dhcpcd-base` | DHCP client (IPv4 only) |
| `linux-sysctl-defaults` | lets users run `ping` without root |
| **Hardening (CIS)** | |
| `apparmor`, `apparmor-utils` | mandatory access control and its tools |
| `libpam-pwquality` | password quality rules |
| `cracklib-runtime` | dictionary for the password check |
| `audispd-plugins` | audit dispatcher plugins (inactive) |
| `aide-common` | AIDE's Debian configuration and daily check |
| `python3-systemd` | lets fail2ban read the journal |

## VMware platform

`platforms/vmware/debian/packages.list`

| Package | Purpose |
|---|---|
| `open-vm-tools` | VMware guest agent; reads the VM properties |
| `cloud-init` | applies the first-boot settings ([`first-boot.md`](first-boot.md)) |
| `cloud-guest-utils` | `growpart`: grows the root partition when the disk grows |

## Docker role

`roles/docker/debian/packages.list`, from Docker's own apt repository
(`download.docker.com`, [`roles/docker.md`](roles/docker.md)).

| Package | Purpose |
|---|---|
| `docker-ce` | Docker Engine (daemon) |
| `docker-ce-cli` | `docker` command |
| `containerd.io` | container runtime |
| `docker-buildx-plugin` | `docker buildx` |
| `docker-compose-plugin` | `docker compose` |

`ca-certificates` and `curl`, which Docker's install guide also installs,
are in [Common](#common-every-os).
