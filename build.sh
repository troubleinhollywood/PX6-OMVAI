#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"
load_config "$ROOT_DIR/config/build.conf"

usage() {
  cat <<EOF_USAGE
$PROJECT_NAME $PROJECT_VERSION
Usage: ./build.sh <command>
Commands: check prepare download verify extract personalize modify-initrd rebuild-initrd patch-bootloader patch-uefi-bootloader rebuild-iso verify-output-iso test-personalization clean status all help
EOF_USAGE
}
show_status() {
  printf 'Project: %s\nVersion: %s\nDebian: %s %s\nOutput ISO: %s\n' "$PROJECT_NAME" "$PROJECT_VERSION" "$DEBIAN_VERSION" "$DEBIAN_ARCH" "$ROOT_DIR/$OUTPUT_ISO"
}
clean_generated() { rm -rf "$ROOT_DIR/$BUILD_DIR" "$ROOT_DIR/$OUTPUT_DIR"; mkdir -p "$ROOT_DIR/$BUILD_DIR" "$ROOT_DIR/$OUTPUT_DIR"; log "Removed generated files"; }

case "${1:-help}" in
  check) "$ROOT_DIR/scripts/check_dependencies.sh" ;;
  prepare) "$ROOT_DIR/scripts/prepare_directories.sh" ;;
  download) "$ROOT_DIR/scripts/prepare_directories.sh"; "$ROOT_DIR/scripts/download_iso.sh" ;;
  verify) "$ROOT_DIR/scripts/verify_iso.sh" ;;
  extract) "$ROOT_DIR/scripts/verify_iso.sh"; "$ROOT_DIR/scripts/prepare_directories.sh"; "$ROOT_DIR/scripts/extract_iso.sh" ;;
  personalize) "$ROOT_DIR/scripts/generate_installer_config.sh" ;;
  modify-initrd) "$ROOT_DIR/scripts/modify_initrd.sh" ;;
  rebuild-initrd) "$ROOT_DIR/scripts/rebuild_initrd.sh" ;;
  patch-bootloader) "$ROOT_DIR/scripts/patch_bootloader.sh" ;;
  patch-uefi-bootloader) "$ROOT_DIR/scripts/patch_uefi_bootloader.sh" ;;
  rebuild-iso) "$ROOT_DIR/scripts/rebuild_iso.sh" ;;
  verify-output-iso) "$ROOT_DIR/scripts/verify_output_iso.sh" ;;
  test-personalization) "$ROOT_DIR/tests/test_personalization.sh" ;;
  clean) clean_generated ;;
  status) show_status ;;
  all)
    : "${PX6_ADMIN_PASSWORD_HASH:?PX6_ADMIN_PASSWORD_HASH is required}"
    : "${PX6_ENABLE_SSH:?PX6_ENABLE_SSH is required}"
    "$ROOT_DIR/scripts/check_dependencies.sh"
    "$ROOT_DIR/scripts/prepare_directories.sh"
    "$ROOT_DIR/scripts/download_iso.sh"
    "$ROOT_DIR/scripts/verify_iso.sh"
    "$ROOT_DIR/scripts/extract_iso.sh"
    "$ROOT_DIR/scripts/generate_installer_config.sh"
    "$ROOT_DIR/scripts/modify_initrd.sh"
    "$ROOT_DIR/scripts/rebuild_initrd.sh"
    "$ROOT_DIR/scripts/patch_bootloader.sh"
    "$ROOT_DIR/scripts/patch_uefi_bootloader.sh"
    "$ROOT_DIR/scripts/rebuild_iso.sh"
    "$ROOT_DIR/scripts/verify_output_iso.sh"
    ;;
  help|-h|--help) usage ;;
  *) usage >&2; die "Unknown build command: ${1:-}" ;;
esac