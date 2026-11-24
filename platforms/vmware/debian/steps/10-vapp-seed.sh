#!/usr/bin/env bash
# vapp-seed: defaults from the build settings, enable the unit.
set -euo pipefail
# shellcheck source=../../../../os/debian/steps/lib.sh
. "$REPO_ROOT/os/debian/steps/lib.sh"

mkdir -p "$TARGET/etc/vapp-seed"
python3 - "$DEFAULT_DOMAIN" "$DEFAULT_USERNAME" "$DEFAULT_TIMEZONE" \
  > "$TARGET/etc/vapp-seed/defaults.json" <<'PY'
import json, sys
domain, user, tz = sys.argv[1:]
print(json.dumps({"vm_domain": domain, "vm_username": user, "vm_timezone": tz}, indent=2))
PY
chmod 644 "$TARGET/etc/vapp-seed/defaults.json"
cat "$TARGET/etc/vapp-seed/defaults.json"

# Release file written at first boot from the hidden vApp property
# template_version: /etc/<prefix>-release with <PREFIX>_TEMPLATE and
# <PREFIX>_VERSION (prefix = OVA_PREFIX, "template" when that is empty).
python3 - "$TEMPLATE" "${OVA_PREFIX:-template}" \
  > "$TARGET/etc/vapp-seed/release.json" <<'PY'
import json, re, sys
template, prefix = sys.argv[1:]
print(json.dumps({"template": template,
                  "file": "/etc/%s-release" % prefix,
                  "prefix": re.sub(r"[^A-Z0-9]", "_", prefix.upper())}, indent=2))
PY
chmod 644 "$TARGET/etc/vapp-seed/release.json"
cat "$TARGET/etc/vapp-seed/release.json"

in_chroot systemctl enable vapp-seed.service vapp-seed-recheck.timer aide-vapp-accept.timer
