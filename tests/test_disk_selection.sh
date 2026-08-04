#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SELECTOR="$ROOT_DIR/scripts/select_target.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$*"
}

actual="$(
  "$SELECTOR" \
    --inventory "$ROOT_DIR/tests/fixtures/safe-single.tsv"
)"

[[ "$actual" == "/dev/sda" ]] ||
  fail "Expected /dev/sda, received $actual"

pass "selects the only non-RAID, non-USB disk"

if "$SELECTOR" \
  --inventory "$ROOT_DIR/tests/fixtures/ambiguous.tsv" \
  >/dev/null 2>&1
then
  fail "Ambiguous inventory was accepted"
fi

pass "rejects multiple safe-looking disks"

raid_only="$(mktemp)"
trap 'rm -f "$raid_only"' EXIT

printf '%s\n' \
  $'/dev/sda\tdisk\t2000398934016\t0\tsata\t-\tlinux_raid_member\t1\tDATA\tD1' \
  > "$raid_only"

if "$SELECTOR" \
  --inventory "$raid_only" \
  >/dev/null 2>&1
then
  fail "RAID-only inventory was accepted"
fi

pass "rejects RAID member disks"

usb_only="$(mktemp)"

printf '%s\n' \
  $'/dev/sdz\tdisk\t120034123776\t1\tusb\t-\t-\t0\tUSB\tUSB1' \
  > "$usb_only"

if "$SELECTOR" \
  --inventory "$usb_only" \
  >/dev/null 2>&1
then
  fail "USB disk was accepted"
fi

rm -f "$usb_only"

pass "rejects USB and removable targets"