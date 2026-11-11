#!/usr/bin/env bash
# Docker's apt repository, set up the way Docker's install guide for
# Debian does it (https://docs.docker.com/engine/install/debian/):
# key /etc/apt/keyrings/docker.asc, source /etc/apt/sources.list.d/docker.sources.
# Runs in the builder before the package lists are installed. The key is
# only used when its fingerprint is Docker's published one.
set -euo pipefail
# shellcheck source=../../../os/debian/steps/lib.sh
. "$REPO_ROOT/os/debian/steps/lib.sh"

DOCKER_URL="https://download.docker.com/linux/debian"
DOCKER_KEY_FPR="9DC858229FC7DD38854AE2D88D81803C0EBFCD88"

log "downloading $DOCKER_URL/gpg"
curl -fsSL --retry 3 --connect-timeout 10 --max-time 60 \
  -o "$STATE/docker.asc" "$DOCKER_URL/gpg" || die "Docker key download failed"
fpr=$(GNUPGHOME="$(mktemp -d)" gpg --show-keys --with-colons "$STATE/docker.asc" 2>/dev/null \
        | awk -F: '$1 == "fpr" {print $10; exit}')
[ "$fpr" = "$DOCKER_KEY_FPR" ] || die "Docker key fingerprint '$fpr' is not $DOCKER_KEY_FPR"
log "Docker key $fpr"

install -d -m 0755 "$TARGET/etc/apt/keyrings"
install -m 0644 "$STATE/docker.asc" "$TARGET/etc/apt/keyrings/docker.asc"

codename=$(. "$TARGET/etc/os-release" && echo "$VERSION_CODENAME")
arch=$(in_chroot dpkg --print-architecture)
cat > "$TARGET/etc/apt/sources.list.d/docker.sources" <<SRC
Types: deb
URIs: $DOCKER_URL
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
SRC
chmod 0644 "$TARGET/etc/apt/sources.list.d/docker.sources"
cat "$TARGET/etc/apt/sources.list.d/docker.sources"
