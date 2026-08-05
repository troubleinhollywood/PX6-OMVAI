#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command cmp
require_command grep
require_command mkdir
require_command readlink
require_command rm
require_command sed
require_command xorriso

original_iso="${1:-$ROOT_DIR/$CACHE_DIR/$DEBIAN_ISO_NAME}"
output_iso="${2:-$ROOT_DIR/$OUTPUT_ISO}"
iso_root="$ROOT_DIR/$ISO_WORK_DIR"
metadata_dir="$ROOT_DIR/$BUILD_DIR/iso-metadata"
extract_dir="$ROOT_DIR/$BUILD_DIR/output-iso-verification"

case "$ROOT_DIR" in
  /mnt/[a-zA-Z]/*)
    die "ISO verification must run from the WSL Linux filesystem, not under /mnt: $ROOT_DIR"
    ;;
esac

[[ -f "$original_iso" ]] ||
  die "Original Debian ISO not found: $original_iso"

[[ -s "$output_iso" ]] ||
  die "Output ISO not found or empty: $output_iso"

[[ "$(readlink -f "$original_iso")" != "$(readlink -f "$output_iso")" ]] ||
  die "Original and output ISO paths must be different"

mkdir -p "$metadata_dir"
rm -rf "$extract_dir"
mkdir -p "$extract_dir"

cleanup() {
  local status=$?
  rm -rf "$extract_dir"
  exit "$status"
}

trap cleanup EXIT

capture_reports() {
  local iso_path="$1"
  local prefix="$2"

  xorriso -indev "$iso_path" -report_el_torito plain \
    > "$metadata_dir/${prefix}-el-torito.txt" 2>&1
  xorriso -indev "$iso_path" -report_system_area plain \
    > "$metadata_dir/${prefix}-system-area.txt" 2>&1
  xorriso -indev "$iso_path" -pvd_info \
    > "$metadata_dir/${prefix}-pvd.txt" 2>&1
  xorriso -indev "$iso_path" -toc \
    > "$metadata_dir/${prefix}-toc.txt" 2>&1
}

extract_volume_id() {
  sed -n "s/^.*Volume id[[:space:]]*:[[:space:]]*'\(.*\)'[[:space:]]*$/\1/p" "$1" |
    head -n 1
}

require_report_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  grep -Eiq "$pattern" "$file" ||
    die "$description is missing from $(basename -- "$file")"
}

compare_feature_presence() {
  local original_report="$1"
  local output_report="$2"
  local pattern="$3"
  local description="$4"
  local original_has=0
  local output_has=0

  grep -Eiq "$pattern" "$original_report" && original_has=1
  grep -Eiq "$pattern" "$output_report" && output_has=1

  [[ "$original_has" -eq "$output_has" ]] ||
    die "$description differs between original and output ISO"

  [[ "$output_has" -eq 1 ]] ||
    die "$description is absent from the original and output ISO"
}

log "Inspecting original and rebuilt ISO boot metadata"

capture_reports "$original_iso" original
capture_reports "$output_iso" output

original_volume_id="$(extract_volume_id "$metadata_dir/original-pvd.txt")"
output_volume_id="$(extract_volume_id "$metadata_dir/output-pvd.txt")"

[[ -n "$original_volume_id" ]] ||
  die "Could not read the original ISO volume label"

[[ "$original_volume_id" == "$output_volume_id" ]] ||
  die "Volume label changed from '$original_volume_id' to '$output_volume_id'"

compare_feature_presence \
  "$metadata_dir/original-el-torito.txt" \
  "$metadata_dir/output-el-torito.txt" \
  'El Torito boot img.*(BIOS|0x00)' \
  "BIOS El Torito boot support"

compare_feature_presence \
  "$metadata_dir/original-el-torito.txt" \
  "$metadata_dir/output-el-torito.txt" \
  'El Torito boot img.*(UEFI|EFI|0xef)' \
  "UEFI El Torito boot support"

compare_feature_presence \
  "$metadata_dir/original-system-area.txt" \
  "$metadata_dir/output-system-area.txt" \
  'isohybrid' \
  "ISOLINUX hybrid MBR"

compare_feature_presence \
  "$metadata_dir/original-system-area.txt" \
  "$metadata_dir/output-system-area.txt" \
  'GPT' \
  "GPT hybrid metadata"

compare_feature_presence \
  "$metadata_dir/original-system-area.txt" \
  "$metadata_dir/output-system-area.txt" \
  'APM' \
  "APM hybrid metadata"

require_report_pattern \
  "$metadata_dir/output-el-torito.txt" \
  'El Torito catalog' \
  "El Torito boot catalog"

modified_files=(
  "install.amd/initrd.gz"
  "isolinux/isolinux.cfg"
  "isolinux/txt.cfg"
)

for relative_path in "${modified_files[@]}"; do
  destination="$extract_dir/$relative_path"
  mkdir -p "$(dirname -- "$destination")"

  xorriso \
    -osirrox on \
    -indev "$output_iso" \
    -extract_single "/$relative_path" "$destination" \
    > /dev/null 2>&1

  [[ -s "$destination" ]] ||
    die "Output ISO is missing: /$relative_path"

  cmp -s "$iso_root/$relative_path" "$destination" ||
    die "Output ISO file differs from the modified source: /$relative_path"
done

grep -q 'auto=true' "$extract_dir/isolinux/txt.cfg" ||
  die "Output boot menu is missing automatic installation"
grep -q 'priority=critical' "$extract_dir/isolinux/txt.cfg" ||
  die "Output boot menu is missing critical installer priority"
grep -q 'preseed/file=/preseed.cfg' "$extract_dir/isolinux/txt.cfg" ||
  die "Output boot menu is missing the embedded preseed path"
grep -q 'console=ttyS0,115200n8' "$extract_dir/isolinux/txt.cfg" ||
  die "Output boot menu is missing the ttyS0 serial console"
grep -q '^serial 0 115200' "$extract_dir/isolinux/isolinux.cfg" ||
  die "Output ISOLINUX configuration is missing serial output"

trap - EXIT
rm -rf "$extract_dir"

log "Verified BIOS, UEFI, hybrid metadata, volume label, and headless installer files"
