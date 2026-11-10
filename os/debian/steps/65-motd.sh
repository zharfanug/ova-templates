#!/usr/bin/env bash
# Login banners and MOTD: /etc/issue and /etc/issue.net come from the
# rootfs overlay; the static MOTD is empty; the zn-motd summary runs in
# every login shell. zn-motd is downloaded at build time (newest release);
# the build fails if it can't be fetched.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ZN_MOTD_URL="https://raw.githubusercontent.com/zharfanug/zn-motd/latest/zn-motd.sh"

: > "$TARGET/etc/motd"
chmod 0644 "$TARGET/etc/motd"
mkdir -p "$TARGET/etc/update-motd.d"
find "$TARGET/etc/update-motd.d" -mindepth 1 -delete

log "downloading $ZN_MOTD_URL"
curl -fsSL --retry 3 --connect-timeout 10 --max-time 60 \
  -o "$STATE/zn-motd.sh" "$ZN_MOTD_URL" || die "zn-motd download failed"
sh -n "$STATE/zn-motd.sh" || die "zn-motd: syntax error"
version=$(sed -n 's/^motd_ver="\(.*\)"$/\1/p' "$STATE/zn-motd.sh")
[ -n "$version" ] || die "zn-motd: no motd_ver in the downloaded file"
log "zn-motd $version"

# Same layout as zn-motd's own installer (motd --update): one executable
# file in profile.d, /usr/local/bin/motd a symlink to it.
install -o root -g root -m 0755 "$STATE/zn-motd.sh" "$TARGET/etc/profile.d/zn-motd.sh"
ln -sfn /etc/profile.d/zn-motd.sh "$TARGET/usr/local/bin/motd"
