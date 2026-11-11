#!/usr/bin/env bash
# Upgrade to the latest point release + security updates, then install the
# OS, platform and role package lists (no recommends).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

lists=("$REPO_ROOT/os/$OS/$VER/packages.list")
lists+=("$REPO_ROOT/platforms/$PLATFORM/$OS/packages.list")
for role in $ROLES; do
  lists+=("$REPO_ROOT/roles/$role/$OS/packages.list")
done

packages=()
for f in "${lists[@]}"; do
  [ -f "$f" ] || continue
  log "packages from ${f#"$REPO_ROOT"/}"
  while read -r pkg _; do
    case "$pkg" in ''|'#'*) continue ;; esac
    packages+=("$pkg")
  done < "$f"
done
[ ${#packages[@]} -gt 0 ] || die "no packages to install"

cp /etc/resolv.conf "$TARGET/etc/resolv.conf"
chroot_mount
# No services start inside the build.
printf '#!/bin/sh\nexit 101\n' > "$TARGET/usr/sbin/policy-rc.d"
chmod 755 "$TARGET/usr/sbin/policy-rc.d"

apt_opts=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# Roles with their own apt repository set it up first:
# roles/<role>/<os>/apt-sources.sh (runs in the builder, like a step).
for role in $ROLES; do
  f="$REPO_ROOT/roles/$role/$OS/apt-sources.sh"
  [ -f "$f" ] || continue
  log "apt sources of role $role"
  bash "$f"
done

in_chroot apt-get update
# debootstrap installs from $SUITE only, without point or security updates.
in_chroot apt-get "${apt_opts[@]}" full-upgrade
in_chroot apt-get "${apt_opts[@]}" install --no-install-recommends "${packages[@]}"
