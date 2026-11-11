#!/usr/bin/env bash
# CI release job: repackage the build kept by build-all.sh with the
# release version - no new build, so the released disks are the ones that
# were built (and tested) from this commit.
#   $OVA_KEEP_DIR/build/  -> build/<ID>/*.ova (+ .ova.sha256, .ovf) here
# Needs PRODUCT_VERSION (from the tag). Fails when the kept build is not
# from the commit being released. Writes the IDs to $GITHUB_OUTPUT.
set -euo pipefail

die() { echo "::error::$*" >&2; exit 1; }

keep="${OVA_KEEP_DIR:-$HOME/ova-builds}"
slot="$keep/build"
: "${PRODUCT_VERSION:?PRODUCT_VERSION is not set}"

[ -s "$slot/COMMIT" ] && [ -s "$slot/BUILDS" ] \
  || die "no successful build kept on this runner: push main and let the build workflow finish first"
have="$(cat "$slot/COMMIT")"
# BUILD_COMMIT: for runs outside a checkout (local tests).
want="${BUILD_COMMIT:-$(git rev-parse HEAD)}"
[ "$have" = "$want" ] \
  || die "the kept build is from ${have:0:12}, the tag is on ${want:0:12}: push main, let the build workflow finish (and test it), then tag"

ids=()
while read -r id template platform; do
  [ -n "$id" ] || continue
  echo "== $id: $template ($platform) -> version $PRODUCT_VERSION"
  mkdir -p build/"$id" logs/"$id"
  cp --sparse=always "$slot/$id/$template-$platform.img" \
    "$slot/$id/$template-$platform-swap.img" build/"$id"/
  # make-ova runs as root in the builder; hand the output back after.
  # shellcheck disable=SC2016  # expanded inside the container
  ID="$id" docker/run.sh sh -c \
    'python3 scripts/make-ova.py "$1" "$2" "build/$3"; rc=$?; chown -R "$HOST_UID:$HOST_GID" "build/$3"; exit $rc' \
    sh "$template" "$platform" "$id" 2>&1 | tee "logs/$id/ova-release-$platform.log"
  rm -f build/"$id"/*.img
  case " ${ids[*]} " in *" $id "*) ;; *) ids+=("$id") ;; esac
done < "$slot/BUILDS"

echo "ids=${ids[*]}" >> "${GITHUB_OUTPUT:-/dev/null}"
