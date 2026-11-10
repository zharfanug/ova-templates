# Build IDs and pruning of build/<ID>/ folders.
# shellcheck shell=bash
#
# <ID> = YYYYMMDDhhmm (build start time, local). build/<ID>/ holds the images and
# OVAs of one run, logs/<ID>/ its logs. Logs are never deleted by the
# scripts; build folders are pruned (see builds_to_prune).

ID_GLOB='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
KEEP_BUILDS="${KEEP_BUILDS:-3}"
KEEP_FINISHED="${KEEP_FINISHED:-2}"

new_id() { date +%Y%m%d%H%M; }

valid_id() {
  # shellcheck disable=SC2254
  case "$1" in $ID_GLOB) return 0 ;; esac
  return 1
}

# Build IDs, newest first (IDs sort by time).
list_builds() {
  local d
  # shellcheck disable=SC2086
  for d in "$REPO_ROOT"/build/$ID_GLOB/; do
    [ -d "$d" ] && basename "$d"
  done | sort -r
}

# A build is finished when it produced at least one OVA.
is_finished() {
  local f
  for f in "$REPO_ROOT/build/$1"/*.ova; do
    [ -f "$f" ] && return 0
  done
  return 1
}

# IDs to delete: everything except the $KEEP_BUILDS newest builds and the
# $KEEP_FINISHED newest finished ones (which may be older when recent
# builds failed), and never <current ID>.
builds_to_prune() {
  local current="$1" d n=0 finished=0 keep=" "
  for d in $(list_builds); do
    n=$((n + 1))
    if [ "$n" -le "$KEEP_BUILDS" ]; then
      keep="$keep$d "
    elif is_finished "$d" && [ "$finished" -lt "$KEEP_FINISHED" ]; then
      keep="$keep$d "
    fi
    if is_finished "$d"; then
      finished=$((finished + 1))
    fi
  done
  for d in $(list_builds); do
    [ "$d" = "$current" ] && continue
    case "$keep" in *" $d "*) continue ;; esac
    echo "$d"
  done
}
