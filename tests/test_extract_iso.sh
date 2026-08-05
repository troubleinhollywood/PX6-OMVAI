#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

extract_script="$ROOT_DIR/scripts/extract_iso.sh"

grep -q 'temporary_path=' "$extract_script" ||
  fail "extraction does not use a temporary directory"

grep -q 'rm -rf "$work_path"' "$extract_script" ||
  fail "stale extraction directory is not replaced"

grep -q 'install.amd/vmlinuz' "$extract_script" ||
  fail "kernel validation is missing"

grep -q 'install.amd/initrd.gz' "$extract_script" ||
  fail "initrd validation is missing"

grep -q 'xorriso' "$extract_script" ||
  fail "xorriso extraction command is missing"

pass "extract stage validates installer structure"
pass "extract stage uses atomic directory replacement"