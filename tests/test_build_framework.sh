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

status_output="$("$ROOT_DIR/build.sh" status)"

grep -q 'Project: PX6-OMVAI' <<<"$status_output" ||
  fail "status did not report project name"

grep -q 'Version: 0.2.0' <<<"$status_output" ||
  fail "status did not report project version"

pass "status reports project configuration"

"$ROOT_DIR/build.sh" prepare

[[ -d "$ROOT_DIR/cache" ]] ||
  fail "cache directory was not created"

[[ -d "$ROOT_DIR/build/iso" ]] ||
  fail "ISO work directory was not created"

[[ -d "$ROOT_DIR/build/initrd" ]] ||
  fail "initrd work directory was not created"

[[ -d "$ROOT_DIR/output" ]] ||
  fail "output directory was not created"

pass "prepare creates required directories"

touch "$ROOT_DIR/build/test-file"
touch "$ROOT_DIR/output/test-file"

"$ROOT_DIR/build.sh" clean

[[ ! -e "$ROOT_DIR/build/test-file" ]] ||
  fail "clean did not remove build files"

[[ ! -e "$ROOT_DIR/output/test-file" ]] ||
  fail "clean did not remove output files"

pass "clean removes generated files"