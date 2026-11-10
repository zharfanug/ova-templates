# Disk layout

Every VM from a template has the same disk layout, created by the build
(no installer): one virtual disk, GPT, UEFI boot, Btrfs with subvolumes.
No encryption, no Secure Boot.

## Partitions

Sizes from the template (`DISK_GB`, `SWAP_GB`); defaults below.

| # | Name | Size | Filesystem | Mount |
|---|---|---|---|---|
| 1 | `esp` | 512 MiB | vfat, label `EFI` | `/boot/efi` (`umask=0077`) |
| 2 | `swap` | 8 GiB | swap, label `swap` | — |
| 3 | `rootfs` | rest (~119.5 GiB of 128 GiB) | Btrfs, label `rootfs` | subvolumes below |

GRUB is installed at the removable path `/EFI/BOOT/BOOTX64.EFI`, so the
VM boots without firmware boot entries. Filesystems are referenced by
UUID in `/etc/fstab` and on the kernel command line.

## Btrfs subvolumes

All subvolumes are mounted with `defaults,noatime,compress=zstd:1`, plus:

| Subvolume | Mount point | Extra options |
|---|---|---|
| `@root` | `/` | — |
| `@home` | `/home` | `nodev,nosuid` |
| `@var` | `/var` | `nodev,nosuid` |
| `@var-tmp` | `/var/tmp` | `nodev,nosuid,noexec` |
| `@log` | `/var/log` | `nodev,nosuid,noexec` |
| `@log-audit` | `/var/log/audit` | `nodev,nosuid,noexec` |
| `@log-archives` | `/var/log/archives` | `nodev,nosuid,noexec` |
| `@tmp` | `/tmp` | `nodev,nosuid,noexec` |
| `@snapshots` | `/.snapshots` | `nodev,nosuid,noexec` |

`/dev/shm` is a tmpfs with `nodev,nosuid,noexec`.

The separate mounts follow the CIS benchmark (separate `/home`, `/var`,
`/var/tmp`, `/var/log`, `/var/log/audit`, `/tmp` with restrictive
options). As subvolumes they share one pool of free space instead of
fixed partition sizes.

## Effects

**One shared pool.** Any subvolume can grow until the filesystem is
full; there are no quotas. `df` shows the same size and free space on
every Btrfs mount; `btrfs filesystem usage /` shows the real allocation.
Data-heavy applications (databases, container storage) should keep
their data on a separate virtual disk so they can't fill the system
pool.

**Compression.** `compress=` applies to the whole filesystem (the first
mount wins), so it is the same `zstd:1` everywhere. `nodev`, `nosuid`,
`noexec` and `noatime` apply per mount.

**`noexec` on `/tmp`, `/var/tmp` and logs.** Programs can't be run from
there: installers that unpack and run code in `/tmp` fail with
"Permission denied". Unpack elsewhere, or run scripts with `sh script`.
`/home` and `/var` stay executable.

**`/tmp` is persistent** (Btrfs, not tmpfs). systemd-tmpfiles removes
old files by its usual age rules.

**`/var` is separate from `/`.** Rolling back `/` from a snapshot would
not roll back the package database in `/var/lib/dpkg`, so snapshots in
`/.snapshots` are meant for data, not for system rollback.

**Swap is a partition**, not a Btrfs swapfile: fixed size, none of the
swapfile restrictions (no compression, no copy-on-write, no snapshots).

## Growing the disk

The Btrfs partition is the last one, so it can grow into new space at
the end of the disk.

1. Enlarge the virtual disk in the hypervisor (works while the VM runs,
   not while it has hypervisor snapshots).
2. Reboot. At boot, cloud-init grows partition 3 to the end of the disk
   and resizes the Btrfs filesystem. Every subvolume gets the new space.
   The ESP and swap keep their size.

Without a reboot:

```sh
echo 1 | sudo tee /sys/class/block/sda/device/rescan
sudo growpart /dev/sda 3
sudo btrfs filesystem resize max /
```

## Adding a disk

A new virtual disk is not used automatically: nothing is partitioned,
formatted or mounted.

1. Add the disk in the hypervisor. If it doesn't show up in `lsblk`,
   rescan the SCSI bus:
   ```sh
   for h in /sys/class/scsi_host/host*/scan; do echo "- - -" | sudo tee $h; done
   ```
2. Set it up as a separate data disk, for example:
   ```sh
   sudo mkfs.btrfs -L data /dev/sdb
   echo 'LABEL=data /srv/data btrfs defaults,noatime,nodev,nosuid,nofail 0 0' | sudo tee -a /etc/fstab
   sudo mkdir -p /srv/data && sudo mount /srv/data
   ```
   `nofail` lets the VM boot without it.

Adding the disk to the system pool (`btrfs device add`) is not
recommended: two disks without redundancy, losing either loses
everything. Grow the main disk instead.
