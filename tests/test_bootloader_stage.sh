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

script="$ROOT_DIR/scripts/patch_bootloader.sh"

grep -q 'default px6-omvai' "$script" ||
  fail "PX6 default boot entry is missing"

grep -q 'menu default' "$script" ||
  fail "PX6 entry is not marked as default"

grep -q 'auto=true' "$script" ||
  fail "automatic installer argument is missing"

grep -q 'priority=critical' "$script" ||
  fail "critical installer priority is missing"

grep -q 'preseed/file=/preseed.cfg' "$script" ||
  fail "embedded preseed argument is missing"

grep -q 'console=ttyS0,115200n8' "$script" ||
  fail "serial kernel console is missing"

grep -q 'serial 0 115200' "$script" ||
  fail "ISOLINUX serial output is missing"

grep -q 'txt.cfg.original' "$script" ||
  fail "boot-menu backup is missing"

pass "defines an unattended PX6 boot entry"
pass "enables serial-console output"
pass "retains original boot configuration backups"