#!/usr/bin/env bash
# Role steps: roles/<role>/<os>/steps/NN-*.sh, per role in ROLES order.
# They run in the builder like these steps (image mounted on $TARGET,
# chroot mounts active) and can source lib.sh. Role build checks are
# roles/<role>/<os>/checks.sh, sourced by 80-checks.sh.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

for role in $ROLES; do
  dir="$REPO_ROOT/roles/$role/$OS/steps"
  [ -d "$dir" ] || continue
  for step in "$dir"/[0-9][0-9]-*.sh; do
    [ -e "$step" ] || continue
    log "role step ${step#"$REPO_ROOT"/}"
    bash "$step"
  done
done
