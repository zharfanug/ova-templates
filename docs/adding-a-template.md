# Adding a template

## Layout

| Path | Content |
|---|---|
| `templates/<name>.env` | one template: OS, version, roles, platforms, disk, virtual hardware |
| `os/<os>/<ver>/vars.env` | release settings (Debian: `SUITE`, mirrors) |
| `os/<os>/<ver>/packages.list` | base packages of that release |
| `os/<os>/steps/NN-*.sh` | build steps for the OS, run in order |
| `os/<os>/rootfs/` | files copied into every image of that OS |
| `platforms/<platform>/ovf/` | OVF descriptor template and hardware settings |
| `platforms/<platform>/<os>/vars.env`, `packages.list`, `steps/` | what the platform adds for that OS (guest agent, first-boot setup) |
| `platforms/<platform>/rootfs/` | files the platform adds |
| `roles/<role>/<os>/packages.list`, `roles/<role>/<os>/rootfs/` | what a role adds (planned) |

File overlays are copied in this order, later ones win: `common/rootfs`,
`os/<os>/rootfs`, `platforms/<platform>/rootfs`, then each role's
`roles/<role>/<os>/rootfs`. Files become root:root, 0644 (0755 when
executable in the repository); steps set other modes.

## A new template for an existing OS

1. Copy `templates/debian-13-amd64-efi.env` to the new name. The name
   is `<os>-<ver>[-<role>...]-<arch>-<firmware>` and must match the
   values inside:

   ```sh
   OS=debian
   VER=13
   ARCH=amd64
   FIRMWARE=efi
   ROLES="docker"          # space-separated, applied in order
   PLATFORMS="vmware"
   DISK_GB=128
   SWAP_GB=8
   CPUS=2
   MEMORY_MB=2048
   ```

2. For each role, add `roles/<role>/<os>/packages.list` and, if needed,
   `roles/<role>/<os>/rootfs/`.
3. Build: `scripts/build.sh <name>`.

## A new release of an existing OS

Add `os/<os>/<ver>/vars.env` and `packages.list` (start from the
previous release), then a template for it. Check the build checks in
`os/<os>/steps/80-checks.sh` for release-specific paths.

## A new platform

Add `platforms/<platform>/` with an OVF template (`ovf/`), the
platform's packages and steps per OS (`<os>/`), and its files
(`rootfs/`). Then list the platform in the template's `PLATFORMS`.
`scripts/make-ova.py` validates every descriptor against the DMTF OVF
schema.

## Build checks

Every setting the image depends on gets a check in
`os/<os>/steps/80-checks.sh` (`need "<what>" <command>`): the build
fails at the first missing one, with `need: <what>` at the end of
`logs/<ID>/image-<platform>.log`.
