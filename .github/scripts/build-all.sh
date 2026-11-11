#!/usr/bin/env bash
# CI build job: build every template, then keep the last successful build
# on the runner, outside the checkout (actions/checkout cleans untracked
# files), for testing and for the release job to repackage:
#   $OVA_KEEP_DIR/build/COMMIT      commit it was built from
#   $OVA_KEEP_DIR/build/BUILDS      "<ID> <template> <platform>" per line
#   $OVA_KEEP_DIR/build/<ID>/       raw images (.img, -swap.img), OVA,
#                                   checksum, descriptor
#   $OVA_KEEP_DIR/logs/<ID>/        logs of every run (never deleted here)
# The build slot is replaced only when every template built.
# Writes the build IDs to $GITHUB_OUTPUT (ids=...).
set -euo pipefail

keep="${OVA_KEEP_DIR:-$HOME/ova-builds}"
ids=()
templates=()
status=0
for t in templates/*.env; do
  name="$(basename "$t" .env)"
  before="$(ls build 2>/dev/null || true)"
  scripts/build.sh "$name" || status=1
  id="$(comm -13 <(echo "$before" | sort) <(ls build | sort) | tail -n1)"
  if [ -n "$id" ]; then
    ids+=("$id")
    templates+=("$name")
  fi
  [ "$status" -eq 0 ] || break
done

mkdir -p "$keep/logs"
for id in "${ids[@]}"; do
  [ -d "logs/$id" ] && cp -a "logs/$id" "$keep/logs/"
done

if [ "$status" -eq 0 ]; then
  new="$keep/build.new"
  rm -rf "$new"
  mkdir -p "$new"
  git rev-parse HEAD > "$new/COMMIT"
  : > "$new/BUILDS"
  for i in "${!ids[@]}"; do
    id="${ids[$i]}" name="${templates[$i]}"
    mkdir -p "$new/$id"
    cp -a --sparse=always build/"$id"/*.img build/"$id"/*.ova \
      build/"$id"/*.ova.sha256 build/"$id"/*.ovf "$new/$id/"
    # One line per platform: <template>-<platform>.img (not -swap.img).
    for img in build/"$id"/"$name"-*.img; do
      case "$img" in *-swap.img) continue ;; esac
      platform="$(basename "$img" .img)"
      echo "$id $name ${platform#"$name"-}" >> "$new/BUILDS"
    done
  done
  rm -rf "$keep/build"
  mv "$new" "$keep/build"
  rm -rf "$keep/latest"   # slot of the previous layout
  echo "kept: $keep/build ($(cat "$keep/build/COMMIT"))"
  cat "$keep/build/BUILDS"
fi

echo "ids=${ids[*]}" >> "${GITHUB_OUTPUT:-/dev/null}"
exit "$status"
