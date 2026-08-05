#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

required_commands=(
  awk
  cat
  cp
  cpio
  find
  grep
  gzip
  mkdir
  paste
  rm
  sed
  sha256sum
  tar
  xorriso
)

missing=()

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    missing+=("$command_name")
  fi
done

if ((${#missing[@]} > 0)); then
  printf '[PX6-OMVAI] Missing dependencies:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

log "All required build dependencies are available"