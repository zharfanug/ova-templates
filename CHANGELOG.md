# Changelog

Every release with what is inside each template (OS, kernel, core
packages) and what changed. Builds always take the latest packages, so a
release can change versions without any change in this repository. The
same notes are on each [GitHub release](https://github.com/zharfanug/ova-templates/releases),
with `<ova>.manifest.json` attached.

## v1.5.0 - 2026-11-28

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.8 (trixie) | 6.12.118+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.8 (trixie) | 6.12.118+deb13-amd64 | 29.10.1 | 2.4.2 | 0.39.1 | 5.8.1 |

### Version changes since v1.4.2

- debian-13-amd64-efi: no version changes
- debian-13-docker-amd64-efi: docker-ce 29.10.0 → 29.10.1, docker-compose-plugin 5.8.0 → 5.8.1

### Changes since v1.4.2

- Stage 23: disk layout: /tmp on tmpfs (4G, nodev,nosuid,noexec), no @log-archives subvolume

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.4.2...v1.5.0

## v1.4.2 - 2026-11-24

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.8 (trixie) | 6.12.118+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.8 (trixie) | 6.12.118+deb13-amd64 | 29.10.0 | 2.4.2 | 0.39.1 | 5.8.0 |

### Version changes since v1.4.1

- debian-13-amd64-efi: Debian 13.7 (trixie) → Debian 13.8 (trixie), kernel 6.12.117+deb13-amd64 → 6.12.118+deb13-amd64
- debian-13-docker-amd64-efi: Debian 13.7 (trixie) → Debian 13.8 (trixie), kernel 6.12.117+deb13-amd64 → 6.12.118+deb13-amd64, docker-ce 29.9.3 → 29.10.0, docker-buildx-plugin 0.39.0 → 0.39.1, docker-compose-plugin 5.7.1 → 5.8.0

### Changes since v1.4.1

- Stage 22: release manifests, changelog, template version in the VM; zn-motd 3.0.0 from GitHub releases

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.4.1...v1.4.2

## v1.4.1 - 2026-11-14

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.117+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.7 (trixie) | 6.12.117+deb13-amd64 | 29.9.3 | 2.4.2 | 0.39.0 | 5.7.1 |

### Version changes since v1.4.0

- debian-13-amd64-efi: kernel 6.12.116+deb13-amd64 → 6.12.117+deb13-amd64
- debian-13-docker-amd64-efi: kernel 6.12.116+deb13-amd64 → 6.12.117+deb13-amd64

### Changes since v1.4.0

- aide-accept: aide must not inherit the lock (fails once an LVM PV exists)

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.4.0...v1.4.1

## v1.4.0 - 2026-11-12

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | 29.9.3 | 2.4.2 | 0.39.0 | 5.7.1 |

### Version changes since v1.3.0

- debian-13-amd64-efi: no version changes
- debian-13-docker-amd64-efi: no version changes

### Changes since v1.3.0

- LVM for data disks: lvm2, thin-provisioning-tools; AIDE ignores /run/lvm

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.3.0...v1.4.0

## v1.3.0 - 2026-11-12

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | 29.9.3 | 2.4.2 | 0.39.0 | 5.7.1 |

### Version changes since v1.2.1

- debian-13-amd64-efi: no version changes
- debian-13-docker-amd64-efi: containerd.io 2.4.2-3~debian.13~trixie → 2.4.2-4~debian.13~trixie, docker-buildx-plugin 0.38.1 → 0.39.0

### Changes since v1.2.1

- Common packages and tools: curl, jq, rsync, unzip, dig, tcpdump, htop, lsof, vim, pip, venv, witr, durank

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.2.1...v1.3.0

## v1.2.1 - 2026-11-11

### Contents

| Template | OS | Kernel | docker-ce | containerd.io | docker-buildx-plugin | docker-compose-plugin |
|---|---|---|---|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | — | — | — | — |
| debian-13-docker-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 | 29.9.3 | 2.4.2 | 0.38.1 | 5.7.1 |

### Version changes since v1.2.0

- debian-13-amd64-efi: no version changes
- debian-13-docker-amd64-efi: new template

### Changes since v1.2.0

- Release: package every kept build (build list was consumed by the builder)

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.2.0...v1.2.1

## v1.2.0 - 2026-11-11

> **Note:** this release contains only the base template. The Docker template (`zn-debian-13-docker-amd64-efi-vmware.ova`) is missing because of a packaging bug; use [v1.2.1](https://github.com/zharfanug/ova-templates/releases/tag/v1.2.1), which has both.

### Contents

| Template | OS | Kernel |
|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 |

### Version changes since v1.1.1

- debian-13-amd64-efi: no version changes

### Changes since v1.1.1

- Role docker: Debian 13 Docker template; role mechanics

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.1.1...v1.2.0

## v1.1.1 - 2026-11-11

### Contents

| Template | OS | Kernel |
|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 |

### Version changes since v1.1.0

- debian-13-amd64-efi: no version changes

### Changes since v1.1.0

- Release repackages the tested build; monthly schedule removed
- swap-grow: let udev re-read the swap disk after mkswap

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.1.0...v1.1.1

## v1.1.0 - 2026-11-11

### Contents

| Template | OS | Kernel |
|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 |

### Version changes since v1.0.0

- debian-13-amd64-efi: no version changes

### Changes since v1.0.0

- Swap on its own disk, disk sizes as build settings, build checks doc

Each template's `<ova>.manifest.json` lists these versions.

**Full Changelog**: https://github.com/zharfanug/ova-templates/compare/v1.0.0...v1.1.0

## v1.0.0 - 2026-11-10

### Contents

| Template | OS | Kernel |
|---|---|---|
| debian-13-amd64-efi | Debian 13.7 (trixie) | 6.12.116+deb13-amd64 |

Each template's `<ova>.manifest.json` lists these versions.
