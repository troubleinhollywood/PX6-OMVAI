#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

mkdir -p \
  "$ROOT_DIR/$CACHE_DIR" \
  "$ROOT_DIR/$BUILD_DIR" \
  "$ROOT_DIR/$OUTPUT_DIR" \
  "$ROOT_DIR/$ISO_WORK_DIR" \
  "$ROOT_DIR/$INITRD_WORK_DIR"

log "Prepared build directories"