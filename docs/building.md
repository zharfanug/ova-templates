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
| `build/<ID>/` | per platform: raw images (`.img`, `-swap.img`), OVA (`.ova`), its checksum (`.ova.sha256`) and the OVF descriptor (`.ovf`, for inspection) |
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

Disk sizes (whole numbers; default from `templates/<name>.env`). Custom
sizes keep the same file names; the OVF records the sizes. Both disks
can also be grown after deployment
([`disk-layout.md`](disk-layout.md)).

| Variable | Default | Used for |
|---|---|---|
| `DISK_GB` | `50` | disk 1 in GiB (ESP + Btrfs), at least 8 |
| `SWAP_GB` | `2` | disk 2 (swap) in GiB, at least 1 |
| `ESP_MIB` | `512` | EFI system partition in MiB, at least 100 |

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
   | `05-disk`, `10-subvolumes` | sparse images (disk 1: GPT, ESP / Btrfs; disk 2: swap), subvolumes |
   | `20-debootstrap`, `30-packages` | base system, package lists, latest updates |
   | `50-rootfs` | file overlays (OS, platform, roles) |
   | `52-swap` … `76-logs` | swap-grow, networking, bootloader, CIS hardening, SSH, banners, firewall, auditd, AIDE, logs |
   | `75-platform` | the platform's own steps (`platforms/<platform>/<os>/steps/`) |
   | `77-roles` | each role's steps (`roles/<role>/<os>/steps/`; role apt sources run in `30-packages`) |
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
file modes, nothing left to upgrade, ...; full list in
[`checks.md`](checks.md)). The first
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
| `build` | push to `main` (not docs-only), manual start | full build; kept on the runner (below); logs, OVF descriptors and checksums as a workflow artifact (14 days) |
| `release` | tag `vX.Y.Z` | **no new build**: the build kept for the tagged commit is repackaged with product version `X.Y.Z` (about a minute); GitHub release with every `.ova`, `.ova.sha256` and `.ovf` |

Builds outside a release use the version `1.0.0.<timestamp>`. Tags in
any other format are refused.

A release contains exactly the disks of the build of its commit, so
that build can be tested before the tag. Order: push `main`, wait for
`build`, test its OVA, then tag that commit. A tag on a commit whose
build isn't the one kept on the runner (not built yet, failed, or a
newer push since) fails with a message and publishes nothing. Only the
OVF descriptor changes (the version); the `.vmdk` files differ in bytes
(a random content ID per conversion), the disk contents are identical
(`qemu-img compare`).

The runner keeps, outside the checkout:

| Path | Contents | Replaced |
|---|---|---|
| `~/ova-builds/build/` | the last successful build: raw images, OVAs, checksums, descriptors, `COMMIT`, `BUILDS` | by every successful `build` run |
| `~/ova-builds/release/` | the last release: OVAs, checksums, descriptors, `TAG` | by every successful `release` run |
| `~/ova-builds/logs/<ID>/` | logs of every run | never (delete by hand) |
