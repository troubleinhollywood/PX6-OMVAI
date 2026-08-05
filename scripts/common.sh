#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  printf '[PX6-OMVAI] %s\n' "$*"
}

warn() {
  printf '[PX6-OMVAI] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[PX6-OMVAI] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "Required command not found: $1"
}

load_config() {
  local file="$1"

  [[ -r "$file" ]] ||
    die "Configuration file not readable: $file"

  # shellcheck disable=SC1090
  source "$file"
}

is_true() {
  local value="${1:-}"

  value="${value//$'\r'/}"

  case "$value" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}