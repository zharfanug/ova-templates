# Disk layout

Every VM from a template has the same disk layout, created by the build
(no installer): two virtual disks, GPT, UEFI boot, Btrfs with
subvolumes, swap on its own disk. No encryption, no Secure Boot.

## Disks and partitions

Sizes are build settings (`DISK_GB`, `SWAP_GB`, `ESP_MIB`, see
[`building.md`](building.md)); the released OVAs use the defaults below.

| Disk | Partition | Size | Filesystem | Mount |
|---|---|---|---|---|
| 1 | 1 `esp` | 512 MiB | vfat, label `EFI` | `/boot/efi` (`umask=0077`) |
| 1 | 2 `rootfs` | rest (~49.5 GiB of 50 GiB) | Btrfs, label `rootfs` | subvolumes below |
| 2 | — (whole disk) | 2 GiB | swap, label `swap` | — |

**Device names are not stable.** Linux names disks in the order it finds
them, so disk 1 can be `sda` on one boot and `sdb` on the next. All
filesystems and the swap are referenced by UUID, so this does not
matter to the system; in commands, find the disk first with
`lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS`.

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

**Swap is a disk of its own**, not a Btrfs swapfile: none of the
swapfile restrictions (no compression, no copy-on-write, no snapshots),
and it can grow like the main disk. Its `/etc/fstab` entry has `nofail`:
without disk 2 the VM boots normally, without swap. No hibernation (the
initramfs never waits for a resume device).

**The swap disk in vSphere** is a normal (dependent) disk, so it is part
of snapshots. To keep it out of snapshots and snapshot-based backups,
set it to **Independent – persistent** (Edit Settings → Hard disk 2 →
Disk Mode; the VM must be off). Backup tools then skip it, which is
fine for swap.

## Growing the main disk

The Btrfs partition is the last one, so it can grow into new space at
the end of the disk.

1. Enlarge disk 1 in the hypervisor (works while the VM runs, not while
   it has hypervisor snapshots).
2. Reboot. At boot, cloud-init grows partition 2 to the end of the disk
   and resizes the Btrfs filesystem. Every subvolume gets the new space.
   The ESP keeps its size.

Without a reboot:

```sh
disk=$(lsblk -nr -o PKNAME "$(findmnt -n -o SOURCE / | sed 's/\[.*//')")
echo 1 | sudo tee /sys/class/block/$disk/device/rescan
sudo growpart /dev/$disk 2
sudo btrfs filesystem resize max /
```

## Changing the swap size

**Larger:** enlarge disk 2 in the hypervisor and reboot. At boot,
`swap-grow.service` re-creates the swap area at the new size, with the
same UUID and label, so `/etc/fstab` still matches
(`journalctl -u swap-grow` shows "swap grown"). It only touches the disk
that already holds this swap, never a blank or other disk.

**Smaller, or a new swap disk:** remove disk 2, add a new disk of the
wanted size, find it with `lsblk` (the empty disk without partitions,
e.g. `/dev/sdb`; double-check, `mkswap` erases it), then format it with
the UUID from `/etc/fstab`:

```sh
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
uuid=$(awk '$3 == "swap" {sub(/^UUID=/, "", $1); print $1}' /etc/fstab)
sudo mkswap -L swap -U "$uuid" /dev/sdX     # the new, empty disk
sudo swapon -a
```

**No swap:** remove disk 2 (and, if you like, the swap line from
`/etc/fstab`).

Removing or adding a disk is a hardware change: the next AIDE check
reports changed `/dev` entries; accept them with `sudo aide-accept`
([`integrity.md`](integrity.md)).

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
   lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS   # find the new, empty disk
   sudo mkfs.btrfs -L data /dev/sdX
   echo 'LABEL=data /srv/data btrfs defaults,noatime,nodev,nosuid,nofail 0 0' | sudo tee -a /etc/fstab
   sudo mkdir -p /srv/data && sudo mount /srv/data
   ```
   `nofail` lets the VM boot without it.

Adding the disk to the system pool (`btrfs device add`) is not
recommended: two disks without redundancy, losing either loses
everything. Grow the main disk instead.
