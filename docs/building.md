# Building

## Requirements

- Linux host with Docker. Your user must be able to run `docker`
  (member of the `docker` group, or run as root).
- About 5 GB free disk space per build (the raw image is sparse).
- Internet access to `deb.debian.org`.

Everything else (debootstrap, Btrfs tools, qemu-img, ...) is inside the
builder image, built automatically from `docker/Dockerfile`.

## Build

```sh
cp .env.example .env                          # optional
scripts/build.sh debian-13-amd64-efi          # all platforms of the template
scripts/build.sh debian-13-amd64-efi vmware   # one platform
```

`<template>` is a file in `templates/` without `.env`.

## Output and logs

Each run gets an ID from its start time, `YYYYMMDDhhmm` (also the
`{timestamp}` in `PRODUCT_VERSION`):

| Path | Contents |
|---|---|
| `build/<ID>/` | per platform: raw image (`.img`), OVA (`.ova`), its checksum (`.ova.sha256`) and the OVF descriptor (`.ovf`, for inspection) |
| `logs/<ID>/build.log` | summary of the run |
| `logs/<ID>/image-<platform>.log` | full log of the image build |
| `logs/<ID>/ova-<platform>.log` | OVA packaging |
| `logs/<ID>/docker-build.log` | builder image |
| `logs/<ID>/prune.log`, `cleanup.log` | pruned builds, loop devices released after a failure |

Logs are never deleted by the scripts. Old build folders are pruned at
the start of each build: the 3 newest builds and the 2 newest finished
builds (with an OVA) are kept.

To reuse an existing build folder instead of starting a new one:

```sh
ID=202611101430 scripts/build.sh debian-13-amd64-efi
```

## Settings (`.env`)

All optional; see `.env.example`. The same names also work as
environment variables, which win over `.env` (e.g.
`PRODUCT_VERSION=1.2.0 scripts/build.sh ...`).

Unset variables use the default; a variable set to `""` leaves the field
out (or, for `OVA_PREFIX`, gives names without a prefix).

| Variable | Default | Used for |
|---|---|---|
| `PRODUCT_NAME` | `ZN {os} {ver} {role} Template` | product name shown on import; `{os}`, `{ver}`, `{role}` filled per template (`ZN Debian 13 Template`) |
| `PRODUCT_VERSION` | `1.0.0.{timestamp}` | product version; `{timestamp}` = build ID (start time, `YYYYMMDDhhmm`) |
| `VENDOR` | `zharfanug` | vendor shown on import |
| `PRODUCT_URL` | `https://github.com/zharfanug/ova-templates` | product link |
| `VENDOR_URL` | `https://github.com/zharfanug` | vendor link |
| `OVA_PREFIX` | `zn` | `<prefix>-` in front of the OVA file name |

Image defaults (empty = default):

| Variable | Default | Used for |
|---|---|---|
| `DEFAULT_DOMAIN` | `example.com` | default domain of a deployed VM |
| `DEFAULT_USERNAME` | `admin` | default admin user of a deployed VM |
| `DEFAULT_TIMEZONE` | `UTC` | default time zone of a deployed VM |

Builder settings (environment variables):

| Variable | Default | Meaning |
|---|---|---|
| `BUILDER_IMAGE` | `ova-templates-builder:latest` | builder image tag |
| `BUILDER_NETWORK` | `host` | Docker network of the builder |

## How it works

1. `scripts/build.sh` (host) creates the ID, prunes old builds, builds
   the builder image and runs the next steps in it.
2. `scripts/build-image.sh` (builder) runs `os/<os>/steps/NN-*.sh` in
   order. For Debian:

   | Step | Does |
   |---|---|
   | `05-disk`, `10-subvolumes` | sparse image, GPT, ESP / swap / Btrfs, subvolumes |
   | `20-debootstrap`, `30-packages` | base system, package lists, latest updates |
   | `50-rootfs` | file overlays (OS, platform, roles) |
   | `55-network` … `76-logs` | networking, bootloader, CIS hardening, SSH, banners, firewall, auditd, AIDE, logs |
   | `75-platform` | the platform's own steps (`platforms/<platform>/<os>/steps/`) |
   | `80-checks` | build checks |
   | `90-cleanup` | per-VM identity removed (machine-id, host keys), free space discarded |
3. `scripts/make-ova.py` (builder) converts the image to a VMDK, writes
   the OVF from `platforms/<platform>/ovf/`, validates it against the
   DMTF OVF 1.1 schema (`scripts/schemas/ovf/`) and packs the OVA.

The builder runs as a privileged container with the host's `/dev`
mounted: building a disk image needs loop devices, partition mappings,
`mount` and `chroot`. It uses host networking by default, so it also
works on hosts whose firewall drops forwarded traffic.

## Build checks

`os/<os>/steps/80-checks.sh` fails the build with `need: <what>` when an
expected result is missing (about 230 checks: disk layout, boot loader,
packages, effective sshd configuration, firewall and audit rules, PAM,
file modes, nothing left to upgrade, ...). The first
failed check is at the end of `logs/<ID>/image-<platform>.log`.

## After a failed build

A failed build releases its own mounts and loop devices. To check that
nothing is left:

```sh
losetup -a
```

## CI and releases

GitHub Actions (`.github/workflows/`) build on a self-hosted runner with
the label `ova-builder` (Linux with Docker, same requirements as above).
Only the repository owner can start a build: there are no pull-request
triggers, and every job checks who started it.

| Workflow | When | Result |
|---|---|---|
| `build` | push to `main` (not docs-only), manual start, monthly | logs, OVF descriptors and checksums as a workflow artifact (14 days) |
| `release` | tag `vX.Y.Z` | product version `X.Y.Z`; GitHub release with every `.ova`, `.ova.sha256` and `.ovf` |

Builds outside a release use the version `1.0.0.<timestamp>`. Tags in
any other format are refused.

The runner keeps the latest successful build's OVAs in
`~/ova-builds/latest/` and the logs of every run in `~/ova-builds/logs/`.
