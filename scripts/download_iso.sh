#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command curl
require_command mkdir
require_command mv
require_command rm

cache_path="$ROOT_DIR/$CACHE_DIR"
iso_path="$cache_path/$DEBIAN_ISO_NAME"
checksum_path="$cache_path/$DEBIAN_CHECKSUM_NAME"

iso_url="$DEBIAN_MIRROR/$DEBIAN_ISO_DIR/$DEBIAN_ISO_NAME"
checksum_url="$DEBIAN_MIRROR/$DEBIAN_ISO_DIR/$DEBIAN_CHECKSUM_NAME"

mkdir -p "$cache_path"

download_file() {
  local url="$1"
  local destination="$2"
  local temporary="${destination}.part"

  rm -f "$temporary"

  log "Downloading $url"

  curl \
    --fail \
    --location \
    --retry 3 \
    --retry-delay 3 \
    --continue-at - \
    --output "$temporary" \
    "$url"

  mv "$temporary" "$destination"
}

if [[ -f "$iso_path" ]]; then
  log "ISO already exists: $iso_path"
else
  download_file "$iso_url" "$iso_path"
fi

download_file "$checksum_url" "$checksum_path"

log "Debian ISO download stage complete"