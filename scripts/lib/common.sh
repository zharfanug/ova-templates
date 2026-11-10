# Shared helpers, sourced by the build scripts (host and container).
# shellcheck shell=bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { log "error: $*"; exit 1; }

# default VAR VALUE: set VAR only if it is unset (an empty value stays
# empty, which leaves the field out).
default() {
  [ -n "${!1+set}" ] || printf -v "$1" '%s' "$2"
}

# .env (optional) -> exported variables with defaults.
load_env() {
  # Environment variables win over .env (CI sets e.g. PRODUCT_VERSION).
  local v saved=()
  for v in PRODUCT_NAME PRODUCT_VERSION VENDOR PRODUCT_URL VENDOR_URL \
           OVA_PREFIX DEFAULT_DOMAIN DEFAULT_USERNAME DEFAULT_TIMEZONE; do
    [ -n "${!v+set}" ] && saved+=("$v=${!v}")
  done
  if [ -f "$REPO_ROOT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$REPO_ROOT/.env"
    set +a
    for v in "${saved[@]}"; do
      export "${v%%=*}=${v#*=}"
    done
  fi
  # Product information and file name prefix: unset -> default,
  # empty -> left out.
  default PRODUCT_NAME 'ZN {os} {ver} {role} Template'
  default PRODUCT_VERSION '1.0.0.{timestamp}'
  default VENDOR 'zharfanug'
  default PRODUCT_URL 'https://github.com/zharfanug/ova-templates'
  default VENDOR_URL 'https://github.com/zharfanug'
  default OVA_PREFIX 'zn'
  # Image defaults: empty -> default.
  : "${DEFAULT_DOMAIN:=example.com}"
  : "${DEFAULT_USERNAME:=admin}"
  : "${DEFAULT_TIMEZONE:=UTC}"
  export PRODUCT_NAME PRODUCT_VERSION PRODUCT_URL VENDOR VENDOR_URL \
    OVA_PREFIX DEFAULT_DOMAIN DEFAULT_USERNAME DEFAULT_TIMEZONE
}

# templates/<name>.env -> exported variables, checked, plus IMAGE_NAME.
# The file name must match its contents:
#   <os>-<ver>[-<role>...]-<arch>-<firmware>
load_template() {
  local name="$1" file="$REPO_ROOT/templates/$1.env" var
  [ -f "$file" ] || die "unknown template: $name (no templates/$name.env)"
  set -a
  # shellcheck disable=SC1090
  . "$file"
  set +a
  for var in OS VER ARCH FIRMWARE PLATFORMS DISK_GB SWAP_GB CPUS MEMORY_MB; do
    [ -n "${!var:-}" ] || die "templates/$name.env: $var is not set"
  done
  : "${ROLES:=}"
  export ROLES

  local roles_part=""
  [ -n "$ROLES" ] && roles_part="-${ROLES// /-}"
  IMAGE_NAME="${OS}-${VER}${roles_part}-${ARCH}-${FIRMWARE}"
  [ "$IMAGE_NAME" = "$name" ] \
    || die "templates/$name.env describes '$IMAGE_NAME'; rename the file or fix its values"
  TEMPLATE="$name"
  export IMAGE_NAME TEMPLATE
}

# True if <platform> is listed in the template's PLATFORMS.
template_supports() {
  case " $PLATFORMS " in *" $1 "*) return 0 ;; esac
  return 1
}

# File names inside build/<ID>/ for one platform.
image_file() { printf '%s-%s.img\n' "$IMAGE_NAME" "$1"; }
ova_file()   { printf '%s%s-%s.ova\n' "${OVA_PREFIX:+$OVA_PREFIX-}" "$IMAGE_NAME" "$1"; }
