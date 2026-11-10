#!/usr/bin/env bash
# Platform steps: platforms/<platform>/<os>/steps/NN-*.sh, in order.
# They run in the builder like these steps (image mounted on $TARGET,
# chroot mounts active) and can source lib.sh.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

dir="$REPO_ROOT/platforms/$PLATFORM/$OS/steps"
[ -d "$dir" ] || exit 0
for step in "$dir"/[0-9][0-9]-*.sh; do
  [ -e "$step" ] || continue
  log "platform step ${step#"$REPO_ROOT"/}"
  bash "$step"
done
