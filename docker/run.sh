#!/usr/bin/env bash
# Build the builder image (cached) and run a command in it, with the repo
# mounted at /work.
#
# Usage:
#   docker/run.sh                  # interactive shell
#   docker/run.sh <command> [args...]
#
# The container runs --privileged: building a disk image needs loop
# devices, device-mapper partition mappings, mount and chroot, which an
# unprivileged container can't do. The host's /dev is mounted because
# loop and device-mapper nodes created during the build would otherwise
# not appear inside the container (its /dev is a copy made at start).
#
# Host networking by default: the container is privileged anyway, and
# hosts with a "forward: drop" firewall policy would otherwise block all
# traffic from the default bridge network (apt, debootstrap, downloads).
#
# Environment:
#   BUILDER_IMAGE     image tag (default: ova-templates-builder:latest)
#   BUILDER_NO_BUILD  set to 1 to skip "docker build" (image already built)
#   BUILDER_NETWORK   docker network for build and run (default: host)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${BUILDER_IMAGE:-ova-templates-builder:latest}"
NETWORK="${BUILDER_NETWORK:-host}"

if [ "${BUILDER_NO_BUILD:-0}" != 1 ]; then
  docker build -q --network "$NETWORK" -t "$IMAGE" -f "$REPO_ROOT/docker/Dockerfile" "$REPO_ROOT/docker" >/dev/null
fi

tty_flags=(-i)
if [ -t 0 ] && [ -t 1 ]; then
  tty_flags=(-it)
fi

# Settings given as environment variables (e.g. in CI) reach the build
# like .env values; -e VAR passes VAR only when it is set.
settings=()
for v in PRODUCT_NAME PRODUCT_VERSION VENDOR PRODUCT_URL VENDOR_URL OVA_PREFIX \
         DEFAULT_DOMAIN DEFAULT_USERNAME DEFAULT_TIMEZONE DISK_GB SWAP_GB ESP_MIB; do
  settings+=(-e "$v")
done

exec docker run --rm "${tty_flags[@]}" \
  --privileged \
  --network "$NETWORK" \
  -v /dev:/dev \
  -v /etc/localtime:/etc/localtime:ro \
  -v "$REPO_ROOT:/work" \
  -w /work \
  -e HOST_UID="$(id -u)" \
  -e ID \
  -e HOST_GID="$(id -g)" \
  "${settings[@]}" \
  "$IMAGE" \
  "$@"
