#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command find
require_command mkdir
require_command rm
require_command xorriso

iso_path="$ROOT_DIR/$CACHE_DIR/$DEBIAN_ISO_NAME"
work_path="$ROOT_DIR/$ISO_WORK_DIR"
temporary_path="${work_path}.partial"

[[ -f "$iso_path" ]] ||
  die "Verified Debian ISO not found: $iso_path"

rm -rf "$temporary_path"
mkdir -p "$temporary_path"

cleanup() {
  local status=$?

  if ((status != 0)); then
    rm -rf "$temporary_path"
  fi

  exit "$status"
}

trap cleanup EXIT

log "Extracting $DEBIAN_ISO_NAME"

xorriso \
  -osirrox on \
  -indev "$iso_path" \
  -extract / "$temporary_path"

required_paths=(
  "install.amd/vmlinuz"
  "install.amd/initrd.gz"
  "isolinux"
  "md5sum.txt"
)

for required_path in "${required_paths[@]}"; do
  [[ -e "$temporary_path/$required_path" ]] ||
    die "Extracted ISO is missing: $required_path"
done

find "$temporary_path" -type d -exec chmod u+rwx {} +
find "$temporary_path" -type f -exec chmod u+rw {} +

rm -rf "$work_path"
mv "$temporary_path" "$work_path"

trap - EXIT

log "Debian ISO extracted to $work_path"