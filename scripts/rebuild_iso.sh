#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command mkdir
require_command mv
require_command readlink
require_command rm
require_command xorriso

original_iso="$ROOT_DIR/$CACHE_DIR/$DEBIAN_ISO_NAME"
iso_root="$ROOT_DIR/$ISO_WORK_DIR"
output_iso="$ROOT_DIR/$OUTPUT_ISO"
temporary_iso="${output_iso}.partial"
metadata_dir="$ROOT_DIR/$BUILD_DIR/iso-metadata"
verify_script="$ROOT_DIR/scripts/verify_output_iso.sh"

case "$ROOT_DIR" in
  /mnt/[a-zA-Z]/*)
    die "ISO rebuilding must run from the WSL Linux filesystem, not under /mnt: $ROOT_DIR"
    ;;
esac

[[ -f "$original_iso" ]] ||
  die "Original Debian ISO not found: $original_iso"

[[ -d "$iso_root" ]] ||
  die "Modified ISO tree not found: $iso_root"

[[ -x "$verify_script" ]] ||
  die "Output ISO verifier is missing or not executable: $verify_script"

required_modified_files=(
  "install.amd/initrd.gz"
  "isolinux/isolinux.cfg"
  "isolinux/txt.cfg"
  "boot/grub/grub.cfg"
)

for relative_path in "${required_modified_files[@]}"; do
  [[ -s "$iso_root/$relative_path" ]] ||
    die "Modified ISO file is missing or empty: $relative_path"
done

grep -q 'console=ttyS0,115200n8' "$iso_root/isolinux/txt.cfg" ||
  die "Modified boot menu is missing the ttyS0 serial-console argument"

grep -q '^serial 0 115200' "$iso_root/isolinux/isolinux.cfg" ||
  die "Modified ISOLINUX configuration is missing serial output"

grep -Fq 'console=ttyS0,115200n8' "$iso_root/boot/grub/grub.cfg" ||
  die "Modified GRUB configuration is missing the ttyS0 serial-console argument"

grep -Fq 'terminal_output serial console' "$iso_root/boot/grub/grub.cfg" ||
  die "Modified GRUB configuration is missing serial output"

original_real="$(readlink -f "$original_iso")"
output_real="$(readlink -m "$output_iso")"

[[ "$original_real" != "$output_real" ]] ||
  die "Output ISO must not overwrite the original Debian ISO"

mkdir -p "$(dirname -- "$output_iso")" "$metadata_dir"
rm -f "$temporary_iso"

cleanup() {
  local status=$?

  if ((status != 0)); then
    rm -f "$temporary_iso"
  fi

  exit "$status"
}

trap cleanup EXIT

log "Recording original Debian ISO boot metadata"

xorriso -indev "$original_iso" -report_el_torito plain \
  > "$metadata_dir/original-el-torito.txt" 2>&1
xorriso -indev "$original_iso" -report_el_torito as_mkisofs \
  > "$metadata_dir/original-el-torito-as-mkisofs.txt" 2>&1
xorriso -indev "$original_iso" -report_system_area plain \
  > "$metadata_dir/original-system-area.txt" 2>&1
xorriso -indev "$original_iso" -report_system_area as_mkisofs \
  > "$metadata_dir/original-system-area-as-mkisofs.txt" 2>&1
xorriso -indev "$original_iso" -pvd_info \
  > "$metadata_dir/original-pvd.txt" 2>&1

log "Rebuilding ISO from Debian boot metadata and modified installer files"

xorriso \
  -abort_on FAILURE \
  -indev "$original_iso" \
  -outdev "$temporary_iso" \
  -overwrite on \
  -map "$iso_root/install.amd/initrd.gz" /install.amd/initrd.gz \
  -map "$iso_root/isolinux/isolinux.cfg" /isolinux/isolinux.cfg \
  -map "$iso_root/isolinux/txt.cfg" /isolinux/txt.cfg \
  -map "$iso_root/boot/grub/grub.cfg" /boot/grub/grub.cfg \
  -boot_image any replay \
  -commit \
  -end

[[ -s "$temporary_iso" ]] ||
  die "Rebuilt ISO was not created: $temporary_iso"

"$verify_script" "$original_iso" "$temporary_iso"

mv -f "$temporary_iso" "$output_iso"
trap - EXIT

log "Bootable PX6-OMVAI ISO created: $output_iso"