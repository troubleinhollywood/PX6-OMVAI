#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "$ROOT_DIR/config/build.conf"

usage() {
  cat <<EOF
$PROJECT_NAME $PROJECT_VERSION

Usage:
  ./build.sh <command>

Commands:
  check
      Validate required build dependencies.

  prepare
      Create cache, build, and output directories.

  download
      Download the Debian installer ISO and checksum file.

  verify
      Verify the cached Debian ISO checksum.

  extract
      Extract the verified Debian ISO into the build directory.

  modify-initrd
      Unpack the Debian installer initrd and inject PX6-OMVAI files.

  rebuild-initrd
      Rebuild the modified Debian installer initrd.

  clean
      Remove generated build and output files.

  status
      Show the current project and build configuration.

  all
      Run all currently implemented build stages.

  help
      Show this help.
EOF
}

show_status() {
  printf 'Project: %s\n' "$PROJECT_NAME"
  printf 'Version: %s\n' "$PROJECT_VERSION"
  printf 'Debian: %s %s\n' "$DEBIAN_VERSION" "$DEBIAN_ARCH"
  printf 'Cache: %s\n' "$ROOT_DIR/$CACHE_DIR"
  printf 'Build: %s\n' "$ROOT_DIR/$BUILD_DIR"
  printf 'ISO work directory: %s\n' "$ROOT_DIR/$ISO_WORK_DIR"
  printf 'Initrd work directory: %s\n' "$ROOT_DIR/$INITRD_WORK_DIR"
  printf 'Output: %s\n' "$ROOT_DIR/$OUTPUT_DIR"
  printf 'Output ISO: %s\n' "$ROOT_DIR/$OUTPUT_ISO"
}

clean_generated() {
  rm -rf \
    "$ROOT_DIR/$BUILD_DIR" \
    "$ROOT_DIR/$OUTPUT_DIR"

  mkdir -p \
    "$ROOT_DIR/$BUILD_DIR" \
    "$ROOT_DIR/$OUTPUT_DIR"

  log "Removed generated build and output files"
}

command_name="${1:-help}"

case "$command_name" in
  check)
    "$ROOT_DIR/scripts/check_dependencies.sh"
    ;;

  prepare)
    "$ROOT_DIR/scripts/prepare_directories.sh"
    ;;

  download)
    "$ROOT_DIR/scripts/prepare_directories.sh"
    "$ROOT_DIR/scripts/download_iso.sh"
    ;;

  verify)
    "$ROOT_DIR/scripts/verify_iso.sh"
    ;;

  extract)
    "$ROOT_DIR/scripts/verify_iso.sh"
    "$ROOT_DIR/scripts/prepare_directories.sh"
    "$ROOT_DIR/scripts/extract_iso.sh"
    ;;

  modify-initrd)
    "$ROOT_DIR/scripts/modify_initrd.sh"
    ;;

  rebuild-initrd)
    "$ROOT_DIR/scripts/rebuild_initrd.sh"
    ;;

  clean)
    clean_generated
    ;;

  status)
    show_status
    ;;

  all)
    "$ROOT_DIR/scripts/check_dependencies.sh"
    "$ROOT_DIR/scripts/prepare_directories.sh"
    "$ROOT_DIR/scripts/download_iso.sh"
    "$ROOT_DIR/scripts/verify_iso.sh"
    "$ROOT_DIR/scripts/extract_iso.sh"
    "$ROOT_DIR/scripts/modify_initrd.sh"
    "$ROOT_DIR/scripts/rebuild_initrd.sh"
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    usage >&2
    die "Unknown build command: $command_name"
    ;;
esac
