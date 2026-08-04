#!/bin/sh
set -eu
LOG=/var/log/px6-target-selection.log
MIN_BYTES=$((25 * 1024 * 1024 * 1024))
CANDIDATES=""

log() { printf '%s\n' "$*" | tee -a "$LOG" >&2; }
fail() {
  log "FATAL: $*"
  debconf-set partman-auto/disk "" || true
  sync
  poweroff -f || halt -f || true
  exit 1
}
is_installer_disk() {
  disk="$1"
  for m in /cdrom /media; do
    src=$(findmnt -n -o SOURCE "$m" 2>/dev/null || true)
    [ -n "$src" ] || continue
    parent=$(lsblk -ndo PKNAME "$src" 2>/dev/null || true)
    [ -n "$parent" ] || parent=$(basename "$src")
    [ "/dev/$parent" = "$disk" ] && return 0
  done
  return 1
}
has_mdraid_metadata() {
  disk="$1"
  mdadm --examine "$disk" >/dev/null 2>&1 && return 0
  for p in "${disk}"[0-9]* "${disk}"p[0-9]*; do
    [ -b "$p" ] || continue
    mdadm --examine "$p" >/dev/null 2>&1 && return 0
  done
  return 1
}
has_lvm_metadata() {
  disk="$1"
  pvs --noheadings -o pv_name 2>/dev/null | awk '{$1=$1};1' |
    grep -Eq "^${disk}([0-9]+|p[0-9]+)?$"
}
has_mounted_child() {
  disk="$1"
  lsblk -nrpo MOUNTPOINT "$disk" 2>/dev/null | grep -q '[^[:space:]]'
}

for disk in $(list-devices disk); do
  [ -b "$disk" ] || continue
  [ "$(lsblk -ndo TYPE "$disk" 2>/dev/null || true)" = "disk" ] ||
    { log "Reject $disk: not whole disk"; continue; }
  [ "$(lsblk -ndo RO "$disk" 2>/dev/null || echo 1)" = "0" ] ||
    { log "Reject $disk: read-only"; continue; }
  size=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
  [ "$size" -ge "$MIN_BYTES" ] ||
    { log "Reject $disk: under 25 GiB"; continue; }
  is_installer_disk "$disk" &&
    { log "Reject $disk: installer media"; continue; }
  has_mounted_child "$disk" &&
    { log "Reject $disk: mounted"; continue; }
  has_mdraid_metadata "$disk" &&
    { log "Reject $disk: mdraid metadata"; continue; }
  has_lvm_metadata "$disk" &&
    { log "Reject $disk: LVM metadata"; continue; }
  log "Eligible target: $disk"
  CANDIDATES="$CANDIDATES $disk"
done

set -- $CANDIDATES
[ "$#" -eq 1 ] || fail "Expected exactly one target, found $#:$CANDIDATES"
TARGET="$1"
log "Selected target: $TARGET"
printf '%s\n' "$TARGET" >/tmp/px6-install-target
debconf-set partman-auto/disk "$TARGET"
