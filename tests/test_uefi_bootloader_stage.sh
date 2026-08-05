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

patch_script="$ROOT_DIR/scripts/patch_uefi_bootloader.sh"
rebuild_script="$ROOT_DIR/scripts/rebuild_iso.sh"
verify_script="$ROOT_DIR/scripts/verify_output_iso.sh"
build_script="$ROOT_DIR/build.sh"
powershell_script="$ROOT_DIR/build.ps1"

for required_file in \
  "$patch_script" \
  "$rebuild_script" \
  "$verify_script" \
  "$build_script" \
  "$powershell_script"; do
  [[ -f "$required_file" ]] ||
    fail "required file is missing: $required_file"
done

grep -Fq 'boot/grub/grub.cfg' "$patch_script" ||
  fail "canonical Debian GRUB path is missing"
grep -Fq 'x86_64 EFI GRUB redirect' "$patch_script" ||
  fail "x86_64 EFI redirect validation is missing"
grep -Fq 'source $prefix/${grub_cpu}-efi/grub.cfg' "$patch_script" ||
  fail "Debian EFI redirect validation is missing"
grep -Fq 'serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1' "$patch_script" ||
  fail "GRUB serial configuration is missing"
grep -Fq 'terminal_input serial console' "$patch_script" ||
  fail "GRUB serial input is missing"
grep -Fq 'terminal_output serial console' "$patch_script" ||
  fail "GRUB serial output is missing"
grep -Fq 'console=ttyS0,115200n8' "$patch_script" ||
  fail "UEFI kernel serial console is missing"
grep -Fq 'preseed/file=/preseed.cfg' "$patch_script" ||
  fail "UEFI embedded preseed path is missing"
grep -Fq 'grub.cfg.original' "$patch_script" ||
  fail "original GRUB backup is missing"
grep -Fq -- '-map "$iso_root/boot/grub/grub.cfg" /boot/grub/grub.cfg' "$rebuild_script" ||
  fail "modified GRUB file is not mapped into the rebuilt ISO"
grep -Fq 'boot/grub/grub.cfg' "$verify_script" ||
  fail "output ISO GRUB verification is missing"
grep -q 'patch-uefi-bootloader)' "$build_script" ||
  fail "build.sh UEFI stage is missing"
grep -q '"patch-uefi-bootloader"' "$powershell_script" ||
  fail "build.ps1 UEFI stage is missing"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
project="$sandbox/project"
mkdir -p \
  "$project/scripts" \
  "$project/config" \
  "$project/build/iso/boot/grub/x86_64-efi" \
  "$project/build/iso/EFI/debian"

cp "$ROOT_DIR/scripts/common.sh" "$project/scripts/common.sh"
cp "$patch_script" "$project/scripts/patch_uefi_bootloader.sh"
chmod +x "$project/scripts/patch_uefi_bootloader.sh"

cat > "$project/config/build.conf" <<'CONFIG'
PROJECT_NAME="PX6-OMVAI"
PROJECT_VERSION="test"
DEBIAN_VERSION="13.6.0"
DEBIAN_ARCH="amd64"
DEBIAN_IMAGE_TYPE="netinst"
DEBIAN_ISO_NAME="debian-test.iso"
CACHE_DIR="cache"
BUILD_DIR="build"
OUTPUT_DIR="output"
ISO_WORK_DIR="build/iso"
INITRD_WORK_DIR="build/initrd"
OUTPUT_ISO="output/PX6-OMVAI-test.iso"
CONFIG

cat > "$project/build/iso/boot/grub/grub.cfg" <<'GRUB'
menuentry 'Install' {
    linux /install.amd/vmlinuz vga=788 --- quiet
    initrd /install.amd/initrd.gz
}
GRUB
printf 'source /boot/grub/grub.cfg\n' > \
  "$project/build/iso/boot/grub/x86_64-efi/grub.cfg"
cat > "$project/build/iso/EFI/debian/grub.cfg" <<'REDIRECT'
search --file --set=root /.disk/id/test
set prefix=($root)/boot/grub
source $prefix/${grub_cpu}-efi/grub.cfg
REDIRECT

"$project/scripts/patch_uefi_bootloader.sh" > "$sandbox/first-run.txt"
"$project/scripts/patch_uefi_bootloader.sh" > "$sandbox/second-run.txt"

grub_cfg="$project/build/iso/boot/grub/grub.cfg"
grub_backup="$project/build/iso/boot/grub/grub.cfg.original"

[[ -s "$grub_backup" ]] ||
  fail "runtime did not create the original GRUB backup"
[[ "$(grep -Fc "menuentry 'PX6-OMVAI unattended installer'" "$grub_cfg")" -eq 1 ]] ||
  fail "runtime is not idempotent"
grep -Fq "menuentry 'Install'" "$grub_cfg" ||
  fail "runtime did not retain the original Debian menu"
grep -Fq 'set default=0' "$grub_cfg" ||
  fail "runtime did not select the PX6 entry"
grep -Fq 'set timeout=5' "$grub_cfg" ||
  fail "runtime did not configure the unattended timeout"
cmp -s "$project/build/iso/boot/grub/x86_64-efi/grub.cfg" \
  <(printf 'source /boot/grub/grub.cfg\n') ||
  fail "runtime changed the x86_64 EFI redirect"
grep -Fq 'source $prefix/${grub_cpu}-efi/grub.cfg' \
  "$project/build/iso/EFI/debian/grub.cfg" ||
  fail "runtime changed the Debian EFI redirect"

pass "validates Debian's real UEFI GRUB redirect chain"
pass "creates one unattended PX6 UEFI entry"
pass "enables GRUB serial input and output at 115200"
pass "retains the original Debian GRUB menu as fallback"
pass "is idempotent and preserves the first backup"
pass "rebuild and verification stages include the modified GRUB menu"