#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"
load_config "$ROOT_DIR/config/px6.conf"

require_command cat
require_command cp
require_command grep
require_command mkdir
require_command sed

iso_root="$ROOT_DIR/$ISO_WORK_DIR"
isolinux_dir="$iso_root/isolinux"
menu_file="$isolinux_dir/txt.cfg"
menu_backup="$isolinux_dir/txt.cfg.original"
isolinux_cfg="$isolinux_dir/isolinux.cfg"
isolinux_backup="$isolinux_dir/isolinux.cfg.original"

[[ -d "$isolinux_dir" ]] ||
  die "Debian ISOLINUX directory not found: $isolinux_dir"

[[ -f "$menu_file" ]] ||
  die "Debian boot menu not found: $menu_file"

[[ -f "$isolinux_cfg" ]] ||
  die "Debian ISOLINUX configuration not found: $isolinux_cfg"

if [[ ! -f "$menu_backup" ]]; then
  cp "$menu_file" "$menu_backup"
fi

if [[ ! -f "$isolinux_backup" ]]; then
  cp "$isolinux_cfg" "$isolinux_backup"
fi

kernel_args=(
  "auto=true"
  "priority=critical"
  "preseed/file=/preseed.cfg"
  "console=tty0"
  "console=ttyS0,115200n8"
  "DEBIAN_FRONTEND=newt"
  "---"
  "quiet"
)

kernel_line="${kernel_args[*]}"

cat > "$menu_file" <<EOF
default px6-omvai

label px6-omvai
    menu label ^PX6-OMVAI unattended installer
    menu default
    kernel /install.amd/vmlinuz
    append initrd=/install.amd/initrd.gz $kernel_line

label original-install
    menu label Debian installer
    kernel /install.amd/vmlinuz
    append initrd=/install.amd/initrd.gz vga=788 --- quiet
EOF

if grep -q '^timeout ' "$isolinux_cfg"; then
  sed -i 's/^timeout .*/timeout 50/' "$isolinux_cfg"
else
  printf '\ntimeout 50\n' >> "$isolinux_cfg"
fi

if grep -q '^default ' "$isolinux_cfg"; then
  sed -i 's/^default .*/default vesamenu.c32/' "$isolinux_cfg"
fi

if ! grep -q '^serial 0 115200' "$isolinux_cfg"; then
  cat >> "$isolinux_cfg" <<'EOF'

serial 0 115200
console 0
EOF
fi

grep -q '^default px6-omvai' "$menu_file" ||
  die "PX6 boot entry was not written"

grep -q 'preseed/file=/preseed.cfg' "$menu_file" ||
  die "Preseed kernel argument is missing"

grep -q 'console=ttyS0,115200n8' "$menu_file" ||
  die "Serial-console kernel argument is missing"

grep -q '^serial 0 115200' "$isolinux_cfg" ||
  die "ISOLINUX serial configuration is missing"

log "Patched Debian BIOS bootloader for unattended PX6 installation"