#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command awk
require_command grep
require_command sha256sum

cache_path="$ROOT_DIR/$CACHE_DIR"
iso_path="$cache_path/$DEBIAN_ISO_NAME"
checksum_path="$cache_path/$DEBIAN_CHECKSUM_NAME"

[[ -f "$iso_path" ]] ||
  die "Debian ISO not found: $iso_path"

[[ -f "$checksum_path" ]] ||
  die "Checksum file not found: $checksum_path"

expected_checksum="$(
  awk -v file="$DEBIAN_ISO_NAME" '
    $2 == file || $2 == "*" file {
      print $1
      exit
    }
  ' "$checksum_path"
)"

[[ -n "$expected_checksum" ]] ||
  die "Checksum for $DEBIAN_ISO_NAME was not found"

actual_checksum="$(
  sha256sum "$iso_path" |
    awk '{ print $1 }'
)"

if [[ "$actual_checksum" != "$expected_checksum" ]]; then
  printf 'Expected: %s\n' "$expected_checksum" >&2
  printf 'Actual:   %s\n' "$actual_checksum" >&2
  die "Debian ISO checksum verification failed"
fi

log "Debian ISO checksum verified"