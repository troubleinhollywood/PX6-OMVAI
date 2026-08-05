#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"
load_config "$ROOT_DIR/config/build.conf"

((EUID == 0)) || die "Initrd processing requires root privileges. Run with sudo."
for command in cpio cp find gzip mkdir mv rm; do require_command "$command"; done

iso_initrd="$ROOT_DIR/$ISO_WORK_DIR/install.amd/initrd.gz"
work_dir="$ROOT_DIR/$INITRD_WORK_DIR"
temporary_dir="${work_dir}.partial"
personalization_dir="$ROOT_DIR/$BUILD_DIR/personalization"

[[ -f "$iso_initrd" ]] || die "Debian installer initrd not found: $iso_initrd"
[[ -f "$personalization_dir/preseed.cfg" ]] || die "Personalized preseed not found. Run ./build.sh personalize first."
[[ -f "$personalization_dir/installer.conf" ]] || die "Installer configuration not found. Run ./build.sh personalize first."
[[ -f "$ROOT_DIR/scripts/common.sh" ]] || die "PX6 common script not found"
[[ -f "$ROOT_DIR/scripts/select_target.sh" ]] || die "PX6 target-selection script not found"
[[ -f "$ROOT_DIR/config/px6.conf" ]] || die "PX6 configuration not found"

rm -rf "$temporary_dir"
mkdir -p "$temporary_dir"
cleanup() { local status=$?; ((status == 0)) || rm -rf "$temporary_dir"; exit "$status"; }
trap cleanup EXIT

log "Unpacking Debian installer initrd"
(
  cd "$temporary_dir"
  gzip -dc "$iso_initrd" | cpio --extract --make-directories --no-absolute-filenames
)

mkdir -p "$temporary_dir/px6-omvai/scripts" "$temporary_dir/px6-omvai/config"
cp "$personalization_dir/preseed.cfg" "$temporary_dir/preseed.cfg"
cp "$personalization_dir/installer.conf" "$temporary_dir/px6-omvai/config/installer.conf"
cp "$ROOT_DIR/scripts/common.sh" "$temporary_dir/px6-omvai/scripts/common.sh"
cp "$ROOT_DIR/scripts/select_target.sh" "$temporary_dir/px6-omvai/scripts/select_target.sh"
cp "$ROOT_DIR/config/px6.conf" "$temporary_dir/px6-omvai/config/px6.conf"
chmod 0755 "$temporary_dir/px6-omvai/scripts/common.sh" "$temporary_dir/px6-omvai/scripts/select_target.sh"
chmod 0600 "$temporary_dir/preseed.cfg" "$temporary_dir/px6-omvai/config/installer.conf"
chmod 0644 "$temporary_dir/px6-omvai/config/px6.conf"
rm -rf "$work_dir"
mv "$temporary_dir" "$work_dir"
trap - EXIT
log "Injected personalized PX6-OMVAI files into installer initrd tree"