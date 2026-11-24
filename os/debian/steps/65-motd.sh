#!/usr/bin/env bash
# Login banners and MOTD: /etc/issue and /etc/issue.net come from the
# rootfs overlay; the static MOTD is empty; the zn-motd summary runs in
# every login shell. zn-motd is downloaded at build time (latest GitHub
# release, checked against its published SHA-256); the build fails if it
# can't be fetched or verified.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ZN_MOTD_URL="https://github.com/zharfanug/zn-motd/releases/latest/download/zn-motd.sh"

: > "$TARGET/etc/motd"
chmod 0644 "$TARGET/etc/motd"
mkdir -p "$TARGET/etc/update-motd.d"
find "$TARGET/etc/update-motd.d" -mindepth 1 -delete

log "downloading $ZN_MOTD_URL"
for f in zn-motd.sh zn-motd.sh.sha256; do
  curl -fsSL --retry 3 --connect-timeout 10 --max-time 60 \
    -o "$STATE/$f" "${ZN_MOTD_URL%/*}/$f" || die "zn-motd: download of $f failed"
done
expected=$(awk '{print $1; exit}' "$STATE/zn-motd.sh.sha256")
actual=$(sha256sum "$STATE/zn-motd.sh" | awk '{print $1}')
[ -n "$expected" ] && [ "$expected" = "$actual" ] \
  || die "zn-motd: checksum mismatch (expected '$expected', got '$actual')"
sh -n "$STATE/zn-motd.sh" || die "zn-motd: syntax error"
version=$(sed -n 's/^motd_ver="\(.*\)"$/\1/p' "$STATE/zn-motd.sh")
[ -n "$version" ] || die "zn-motd: no motd_ver in the downloaded file"
log "zn-motd $version (sha256 $actual)"

# Same layout as zn-motd's own installer (motd --update replaces it in
# place): the script is /etc/profile.d/.zn-motd.sh (the dot keeps it out
# of /etc/profile's *.sh loop); /etc/profile.d/zn-motd.sh is a shim that
# runs it as a child process, so an exit in zn-motd can't end the login
# shell; /usr/local/bin/motd is a symlink to the script.
real=/etc/profile.d/.zn-motd.sh
install -o root -g root -m 0755 "$STATE/zn-motd.sh" "$TARGET$real"
printf '#!/bin/sh\n[ -x "%s" ] && "%s"\n' "$real" "$real" > "$TARGET/etc/profile.d/zn-motd.sh"
chown root:root "$TARGET/etc/profile.d/zn-motd.sh"
chmod 0755 "$TARGET/etc/profile.d/zn-motd.sh"
ln -sfn "$real" "$TARGET/usr/local/bin/motd"
