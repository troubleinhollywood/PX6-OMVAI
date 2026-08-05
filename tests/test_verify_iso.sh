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

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

printf 'PX6-OMVAI test ISO\n' > "$temp_dir/test.iso"

checksum="$(
  sha256sum "$temp_dir/test.iso" |
    awk '{ print $1 }'
)"

printf '%s  test.iso\n' "$checksum" > "$temp_dir/SHA256SUMS"

expected="$(
  awk '$2 == "test.iso" { print $1 }' \
    "$temp_dir/SHA256SUMS"
)"

actual="$(
  sha256sum "$temp_dir/test.iso" |
    awk '{ print $1 }'
)"

[[ "$expected" == "$actual" ]] ||
  fail "valid checksum was rejected"

pass "accepts a valid ISO checksum"

printf 'modified\n' >> "$temp_dir/test.iso"

actual="$(
  sha256sum "$temp_dir/test.iso" |
    awk '{ print $1 }'
)"

[[ "$expected" != "$actual" ]] ||
  fail "modified ISO matched original checksum"

pass "detects a modified ISO"