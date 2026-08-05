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

rebuild_script="$ROOT_DIR/scripts/rebuild_iso.sh"
verify_script="$ROOT_DIR/scripts/verify_output_iso.sh"
build_script="$ROOT_DIR/build.sh"
powershell_script="$ROOT_DIR/build.ps1"

for required_file in \
  "$rebuild_script" \
  "$verify_script" \
  "$build_script" \
  "$powershell_script"; do
  [[ -f "$required_file" ]] ||
    fail "required file is missing: $required_file"
done

grep -q -- '-boot_image any replay' "$rebuild_script" ||
  fail "xorriso boot replay is missing"

grep -q -- '-indev "$original_iso"' "$rebuild_script" ||
  fail "original ISO is not used as the metadata source"

grep -q -- '-map "$iso_root/install.amd/initrd.gz" /install.amd/initrd.gz' "$rebuild_script" ||
  fail "modified initrd is not replaced"

grep -q -- '-map "$iso_root/isolinux/isolinux.cfg" /isolinux/isolinux.cfg' "$rebuild_script" ||
  fail "modified ISOLINUX configuration is not replaced"

grep -q -- '-map "$iso_root/isolinux/txt.cfg" /isolinux/txt.cfg' "$rebuild_script" ||
  fail "modified boot menu is not replaced"

if grep -Eq -- '(-b[[:space:]]+|eltorito-boot|isohdpfx|efi\.img|isolinux\.bin)' "$rebuild_script"; then
  fail "rebuild script contains guessed boot-image parameters"
fi

if grep -Eq '\beval\b' "$rebuild_script" "$verify_script"; then
  fail "generated xorriso report text must not be evaluated"
fi

grep -q 'rebuild-iso)' "$build_script" ||
  fail "build.sh rebuild-iso command is missing"

grep -q 'verify-output-iso)' "$build_script" ||
  fail "build.sh verify-output-iso command is missing"

grep -q '"rebuild-iso"' "$powershell_script" ||
  fail "build.ps1 rebuild-iso command is missing"

grep -q '"verify-output-iso"' "$powershell_script" ||
  fail "build.ps1 verify-output-iso command is missing"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

project="$sandbox/project"
mkdir -p \
  "$project/scripts" \
  "$project/config" \
  "$project/cache" \
  "$project/build/iso/install.amd" \
  "$project/build/iso/isolinux" \
  "$project/output" \
  "$sandbox/bin"

cp "$ROOT_DIR/scripts/common.sh" "$project/scripts/common.sh"
cp "$rebuild_script" "$project/scripts/rebuild_iso.sh"
cp "$verify_script" "$project/scripts/verify_output_iso.sh"
chmod +x \
  "$project/scripts/rebuild_iso.sh" \
  "$project/scripts/verify_output_iso.sh"

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

printf 'original iso\n' > "$project/cache/debian-test.iso"
printf 'modified initrd\n' > "$project/build/iso/install.amd/initrd.gz"
cat > "$project/build/iso/isolinux/txt.cfg" <<'MENU'
default px6-omvai
append auto=true priority=critical preseed/file=/preseed.cfg console=tty0 console=ttyS0,115200n8 DEBIAN_FRONTEND=newt
MENU
cat > "$project/build/iso/isolinux/isolinux.cfg" <<'ISOLINUX'
default vesamenu.c32
serial 0 115200
console 0
ISOLINUX

cat > "$sandbox/bin/xorriso" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%s\n' "$*" >> "$MOCK_XORRISO_LOG"

arguments=" $* "

if [[ "$arguments" == *" -pvd_info "* ]]; then
  printf "Volume id    : 'DEBIAN_TEST'\n"
  exit 0
fi

if [[ "$arguments" == *" -report_el_torito "* ]]; then
  printf 'El Torito catalog  : 33  1\n'
  printf 'El Torito boot img : 1  BIOS  y   none\n'
  printf 'El Torito boot img : 2  UEFI  y   none\n'
  exit 0
fi

if [[ "$arguments" == *" -report_system_area "* ]]; then
  printf 'System area options: 0x00000201\n'
  printf 'System area summary: MBR isohybrid cyl-align-on GPT APM\n'
  exit 0
fi

if [[ "$arguments" == *" -toc "* ]]; then
  printf 'ISO image size: 100 sectors\n'
  exit 0
fi

if [[ "$arguments" == *" -extract_single "* ]]; then
  source_path=''
  destination=''
  previous=''

  for argument in "$@"; do
    if [[ "$previous" == '-extract_single' ]]; then
      source_path="$argument"
    elif [[ -n "$source_path" && -z "$destination" && "$previous" == "$source_path" ]]; then
      destination="$argument"
      break
    fi
    previous="$argument"
  done

  source_path="${source_path#/}"
  mkdir -p "$(dirname -- "$destination")"
  cp "$MOCK_ISO_TREE/$source_path" "$destination"
  exit 0
fi

output=''
previous=''
for argument in "$@"; do
  if [[ "$previous" == '-outdev' ]]; then
    output="$argument"
    break
  fi
  previous="$argument"
done

if [[ -n "$output" ]]; then
  printf 'mock rebuilt iso\n' > "$output"
fi
MOCK
chmod +x "$sandbox/bin/xorriso"

export MOCK_XORRISO_LOG="$sandbox/xorriso.log"
export MOCK_ISO_TREE="$project/build/iso"
PATH="$sandbox/bin:$PATH" "$project/scripts/rebuild_iso.sh" \
  > "$sandbox/rebuild-output.txt"

[[ -s "$project/output/PX6-OMVAI-test.iso" ]] ||
  fail "mock runtime did not create the final ISO"

[[ ! -e "$project/output/PX6-OMVAI-test.iso.partial" ]] ||
  fail "temporary ISO was not removed after successful verification"

grep -q -- '-boot_image any replay' "$sandbox/xorriso.log" ||
  fail "mock runtime did not invoke boot replay"

grep -q 'Verified BIOS, UEFI, hybrid metadata, volume label, and headless installer files' \
  "$sandbox/rebuild-output.txt" ||
  fail "mock runtime did not complete output verification"

pass "rebuild stage derives boot configuration from the original ISO"
pass "rebuild stage replaces only modified installer files"
pass "verification checks BIOS, UEFI, MBR, GPT, APM, and volume label"
pass "verification checks unattended ttyS0 boot configuration"
pass "build.sh and build.ps1 expose the new stages"
pass "mock rebuild completes verification before publishing the ISO"
