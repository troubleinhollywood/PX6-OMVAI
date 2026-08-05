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

modify_script="$ROOT_DIR/scripts/modify_initrd.sh"
rebuild_script="$ROOT_DIR/scripts/rebuild_initrd.sh"
preseed="$ROOT_DIR/preseed/preseed.cfg"

grep -q 'gzip -dc' "$modify_script" ||
  fail "initrd unpack command is missing"

grep -q 'cpio --extract' "$modify_script" ||
  fail "initrd extraction command is missing"

grep -q 'preseed.cfg' "$modify_script" ||
  fail "preseed injection is missing"

grep -q 'select_target.sh' "$modify_script" ||
  fail "disk selector injection is missing"

grep -q 'gzip -9n' "$rebuild_script" ||
  fail "deterministic gzip rebuild is missing"

grep -q 'format=newc' "$rebuild_script" ||
  fail "newc cpio rebuild is missing"

grep -q 'passwd/root-login boolean false' "$preseed" ||
  fail "root login policy is missing"

grep -q 'ssh-server' "$preseed" ||
  fail "SSH installation is missing"

pass "initrd unpack stage is defined"
pass "PX6 files are injected"
pass "initrd rebuild is reproducible"
pass "preseed contains base unattended settings"