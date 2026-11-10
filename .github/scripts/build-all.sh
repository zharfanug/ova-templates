#!/usr/bin/env bash
# CI: build every template, then keep the latest working build on the
# runner outside the checkout (actions/checkout cleans untracked files):
#   $OVA_KEEP_DIR/latest/   OVAs, checksums, descriptors of the last successful run
#   $OVA_KEEP_DIR/logs/<ID>/  logs of every run (never deleted here)
# Writes the build IDs to $GITHUB_OUTPUT (ids=...).
set -euo pipefail

keep="${OVA_KEEP_DIR:-$HOME/ova-builds}"
ids=()
status=0
for t in templates/*.env; do
  name="$(basename "$t" .env)"
  before="$(ls build 2>/dev/null || true)"
  scripts/build.sh "$name" || status=1
  id="$(comm -13 <(echo "$before" | sort) <(ls build | sort) | tail -n1)"
  [ -n "$id" ] && ids+=("$id")
  [ "$status" -eq 0 ] || break
done

mkdir -p "$keep/logs"
for id in "${ids[@]}"; do
  [ -d "logs/$id" ] && cp -a "logs/$id" "$keep/logs/"
done

if [ "$status" -eq 0 ]; then
  rm -rf "$keep/latest.new"
  mkdir -p "$keep/latest.new"
  for id in "${ids[@]}"; do
    cp -a build/"$id"/*.ova build/"$id"/*.ova.sha256 build/"$id"/*.ovf "$keep/latest.new/"
    echo "$id" >> "$keep/latest.new/BUILD_IDS"
    rm -f build/"$id"/*.img
  done
  rm -rf "$keep/latest"
  mv "$keep/latest.new" "$keep/latest"
fi

echo "ids=${ids[*]}" >> "${GITHUB_OUTPUT:-/dev/null}"
exit "$status"
