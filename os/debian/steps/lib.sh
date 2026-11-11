# Shared by the Debian build steps (sourced). Runs in the builder container.
# shellcheck shell=bash disable=SC2034  # variables are used by the steps
#
# Set by scripts/build-image.sh: TEMPLATE, PLATFORM, OS, VER, ARCH,
# DISK_GB, SWAP_GB, ESP_MIB, ROLES, SUITE, MIRROR, SECURITY_MIRROR, IMAGE,
# SWAP_IMAGE, IMAGE_HOSTNAME, TARGET (mounted root), STATE (scratch dir).

# shellcheck source=../../../scripts/lib/common.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/lib/common.sh"

BTRFS_OPTS="defaults,noatime,compress=zstd:1"
SWAP_OPTS="sw,nofail,x-systemd.device-timeout=10s"

# Btrfs subvolumes: "<name> <mount point> [extra options]", in mount order
# (parents first). Single source for create, mount, fstab and checks.
SUBVOLS=(
  "@root          /"
  "@home          /home              nodev,nosuid"
  "@var           /var               nodev,nosuid"
  "@log           /var/log           nodev,nosuid,noexec"
  "@log-audit     /var/log/audit     nodev,nosuid,noexec"
  "@log-archives  /var/log/archives  nodev,nosuid,noexec"
  "@tmp           /tmp               nodev,nosuid,noexec"
  "@var-tmp       /var/tmp           nodev,nosuid,noexec"
  "@snapshots     /.snapshots        nodev,nosuid,noexec"
)

# World-writable sticky directories.
STICKY_DIRS=(/tmp /var/tmp)

# Mount options of one subvolume entry: base + extra + subvol=.
subvol_opts() {
  local name="$1" extra="${3:-}"
  printf '%s%s,subvol=%s\n' "$BTRFS_OPTS" "${extra:+,$extra}" "$name"
}

# Device paths written by 05-disk.sh.
load_devs() {
  # shellcheck disable=SC1091
  . "$STATE/devs.env"
}

# need <description> <command...>: build check, fails the build if the
# command fails.
need() {
  local what="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    log "ok: $what"
  else
    die "need: $what"
  fi
}

# Run a command inside the image (chroot mounts from 30-packages.sh).
in_chroot() {
  chroot "$TARGET" /usr/bin/env -i \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    HOME=/root LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive \
    "$@"
}

chroot_mount() {
  local m
  for m in dev dev/pts proc sys; do
    mountpoint -q "$TARGET/$m" && continue
    case "$m" in
      dev) mount --bind /dev "$TARGET/dev" ;;
      dev/pts) mount -t devpts devpts "$TARGET/dev/pts" ;;
      proc) mount -t proc proc "$TARGET/proc" ;;
      sys) mount --bind /sys "$TARGET/sys" ;;
    esac
  done
}

chroot_umount() {
  local m
  for m in sys proc dev/pts dev; do
    if mountpoint -q "$TARGET/$m"; then
      umount "$TARGET/$m"
    fi
  done
}
