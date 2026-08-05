#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

if ((EUID != 0)); then
  die "Initrd processing requires root privileges. Run with sudo."
fi

require_command cpio
require_command find
require_command gzip
require_command mv
require_command rm
require_command sort

work_dir="$ROOT_DIR/$INITRD_WORK_DIR"
destination="$ROOT_DIR/$ISO_WORK_DIR/install.amd/initrd.gz"
temporary="${destination}.partial"

[[ -d "$work_dir" ]] ||
  die "Modified initrd tree not found: $work_dir"

[[ -f "$work_dir/preseed.cfg" ]] ||
  die "Modified initrd is missing preseed.cfg"

[[ -f "$work_dir/px6-omvai/config/px6.conf" ]] ||
  die "Modified initrd is missing px6.conf"

[[ -x "$work_dir/px6-omvai/scripts/common.sh" ]] ||
  die "Modified initrd is missing executable common.sh"

[[ -x "$work_dir/px6-omvai/scripts/select_target.sh" ]] ||
  die "Modified initrd is missing executable disk selector"

rm -f "$temporary"

cleanup() {
  local status=$?

  if ((status != 0)); then
    rm -f "$temporary"
  fi

  exit "$status"
}

trap cleanup EXIT

log "Rebuilding Debian installer initrd"

(
  cd "$work_dir"

  find . \
    -print0 |
    LC_ALL=C sort -z |
    cpio \
      --null \
      --create \
      --format=newc \
      --owner=0:0 |
    gzip -9n > "$temporary"
)

[[ -s "$temporary" ]] ||
  die "Rebuilt initrd is empty"

mv "$temporary" "$destination"

trap - EXIT

log "Rebuilt installer initrd: $destination"
