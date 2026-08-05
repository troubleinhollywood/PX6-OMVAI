#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

require_command cat
require_command cp
require_command grep
require_command mkdir
require_command mv
require_command rm

iso_root="$ROOT_DIR/$ISO_WORK_DIR"
grub_cfg="$iso_root/boot/grub/grub.cfg"
grub_backup="$iso_root/boot/grub/grub.cfg.original"
grub_efi_redirect="$iso_root/boot/grub/x86_64-efi/grub.cfg"
debian_efi_redirect="$iso_root/EFI/debian/grub.cfg"
temporary_cfg="${grub_cfg}.tmp"

[[ -f "$grub_cfg" ]] ||
  die "Debian GRUB menu not found: $grub_cfg"

[[ -f "$grub_efi_redirect" ]] ||
  die "Debian x86_64 EFI GRUB redirect not found: $grub_efi_redirect"

[[ -f "$debian_efi_redirect" ]] ||
  die "Debian EFI loader configuration not found: $debian_efi_redirect"

grep -Eq '^[[:space:]]*source[[:space:]]+/boot/grub/grub\.cfg[[:space:]]*$' \
  "$grub_efi_redirect" ||
  die "Unexpected x86_64 EFI GRUB redirect chain: $grub_efi_redirect"

grep -Fq 'source $prefix/${grub_cpu}-efi/grub.cfg' \
  "$debian_efi_redirect" ||
  die "Unexpected Debian EFI GRUB redirect chain: $debian_efi_redirect"

if [[ ! -f "$grub_backup" ]]; then
  cp "$grub_cfg" "$grub_backup"
fi

[[ -s "$grub_backup" ]] ||
  die "Debian GRUB backup is missing or empty: $grub_backup"

cleanup() {
  local status=$?
  rm -f "$temporary_cfg"
  exit "$status"
}

trap cleanup EXIT

cat > "$temporary_cfg" <<'GRUB_HEADER'
# PX6-OMVAI managed UEFI boot configuration
serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1
terminal_input serial console
terminal_output serial console
set default=0
set timeout=5

menuentry 'PX6-OMVAI unattended installer' --id px6-omvai {
    set background_color=black
    linux /install.amd/vmlinuz auto=true priority=critical preseed/file=/preseed.cfg console=tty0 console=ttyS0,115200n8 DEBIAN_FRONTEND=newt --- quiet
    initrd /install.amd/initrd.gz
}

# Original Debian installer menu follows.
GRUB_HEADER

cat "$grub_backup" >> "$temporary_cfg"
mv "$temporary_cfg" "$grub_cfg"
trap - EXIT

px6_entry_count="$(grep -Fc "menuentry 'PX6-OMVAI unattended installer'" "$grub_cfg")"
[[ "$px6_entry_count" -eq 1 ]] ||
  die "Expected exactly one PX6 UEFI menu entry, found: $px6_entry_count"

grep -Fq 'serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1' "$grub_cfg" ||
  die "GRUB serial-port configuration is missing"

grep -Fq 'terminal_input serial console' "$grub_cfg" ||
  die "GRUB serial input is missing"

grep -Fq 'terminal_output serial console' "$grub_cfg" ||
  die "GRUB serial output is missing"

grep -Fq 'preseed/file=/preseed.cfg' "$grub_cfg" ||
  die "UEFI boot entry is missing the embedded preseed path"

grep -Fq 'console=ttyS0,115200n8' "$grub_cfg" ||
  die "UEFI boot entry is missing the ttyS0 serial console"

grep -Eq '^set default=0$' "$grub_cfg" ||
  die "PX6 UEFI boot entry is not the default"

grep -Eq '^set timeout=5$' "$grub_cfg" ||
  die "PX6 UEFI boot timeout is not configured"

log "Patched Debian UEFI GRUB for unattended PX6 serial-console installation"