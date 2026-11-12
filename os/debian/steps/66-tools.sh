#!/usr/bin/env bash
# Common tools that are not Debian packages, downloaded at build time to
# /usr/local/bin (docs/packages.md); the build fails if a download fails.
#   witr    pranshuparmar/witr: latest release binary, checked against the
#           release's SHA256SUMS
#   durank  zharfanug/linux-helper (tag latest): durank.sh
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

WITR_URL="https://github.com/pranshuparmar/witr/releases/latest/download"
DURANK_URL="https://raw.githubusercontent.com/zharfanug/linux-helper/latest/durank.sh"

fetch() { curl -fsSL --retry 3 --connect-timeout 10 --max-time 120 -o "$1" "$2"; }

# --- witr ----------------------------------------------------------------------
log "downloading $WITR_URL/witr-linux-$ARCH"
fetch "$STATE/witr" "$WITR_URL/witr-linux-$ARCH" || die "witr download failed"
fetch "$STATE/witr.sums" "$WITR_URL/SHA256SUMS" || die "witr SHA256SUMS download failed"
want=$(awk -v f="witr-linux-$ARCH" '$2 == f || $2 == "*" f {print $1}' "$STATE/witr.sums")
[ -n "$want" ] || die "witr: no checksum for witr-linux-$ARCH in SHA256SUMS"
have=$(sha256sum "$STATE/witr" | awk '{print $1}')
[ "$have" = "$want" ] || die "witr: checksum mismatch ($have, SHA256SUMS: $want)"
install -o root -g root -m 0755 "$STATE/witr" "$TARGET/usr/local/bin/witr"
log "witr $(in_chroot /usr/local/bin/witr --version 2>/dev/null | head -n1)"

# --- durank --------------------------------------------------------------------
log "downloading $DURANK_URL"
fetch "$STATE/durank" "$DURANK_URL" || die "durank download failed"
sh -n "$STATE/durank" || die "durank: syntax error"
install -o root -g root -m 0755 "$STATE/durank" "$TARGET/usr/local/bin/durank"
