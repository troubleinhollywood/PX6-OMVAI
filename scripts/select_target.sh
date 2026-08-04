#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

load_config "${PX6_CONFIG:-$ROOT_DIR/config/px6.conf}"

inventory_file=""
explain=0

usage() {
  cat <<'EOF'
Usage:
  scripts/select_target.sh [--inventory FILE] [--explain]

Options:
  --inventory FILE
      Read a tab-separated disk inventory from FILE instead of probing the
      current system.

  --explain
      Print the reason each rejected disk was excluded.

Inventory columns:
  NAME TYPE SIZE RM TRAN MOUNTPOINTS FSTYPE MD_MEMBER MODEL SERIAL

Result:
  Prints exactly one safe whole-disk path and exits successfully.

  Refuses installation when:
    - no safe target exists
    - more than one safe-looking target exists
    - a disk is removable or connected through USB
    - a disk or child partition is mounted
    - Linux RAID metadata is detected
EOF
}

while (($#)); do
  case "$1" in
    --inventory)
      [[ $# -ge 2 ]] || die "Missing path after --inventory"
      inventory_file="$2"
      shift 2
      ;;

    --explain)
      explain=1
      shift
      ;;

    -h|--help)
      usage
      exit 0
      ;;

    *)
      die "Unknown argument: $1"
      ;;
  esac
done

reject() {
  local disk="$1"
  local reason="$2"

  if ((explain)); then
    printf 'REJECT\t%s\t%s\n' "$disk" "$reason" >&2
  fi
}

emit_inventory() {
  if [[ -n "$inventory_file" ]]; then
    [[ -r "$inventory_file" ]] ||
      die "Inventory file not readable: $inventory_file"

    cat "$inventory_file"
    return
  fi

  require_command lsblk
  require_command awk
  require_command grep
  require_command paste
  require_command sed

  local name
  local path
  local type
  local size
  local rm
  local tran
  local mounts
  local fstype
  local model
  local serial
  local md_member

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue

    path="/dev/$name"
    type="$(lsblk -dnro TYPE "$path")"
    size="$(lsblk -bdnro SIZE "$path")"
    rm="$(lsblk -dnro RM "$path")"
    tran="$(lsblk -dnro TRAN "$path" 2>/dev/null || true)"

    mounts="$(
      lsblk -nrpo MOUNTPOINTS "$path" |
        awk 'NF' |
        paste -sd, -
    )"

    fstype="$(lsblk -dnro FSTYPE "$path" 2>/dev/null || true)"

    model="$(
      lsblk -dnro MODEL "$path" 2>/dev/null |
        sed 's/[[:space:]]*$//'
    )"

    serial="$(
      lsblk -dnro SERIAL "$path" 2>/dev/null |
        sed 's/[[:space:]]*$//'
    )"

    md_member=0

    if lsblk -nrpo FSTYPE "$path" |
      grep -qx 'linux_raid_member'; then
      md_member=1
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$path" \
      "$type" \
      "$size" \
      "$rm" \
      "$tran" \
      "$mounts" \
      "$fstype" \
      "$md_member" \
      "$model" \
      "$serial"

  done < <(
    lsblk -dnro NAME,TYPE |
      awk '$2 == "disk" { print $1 }'
  )
}

candidates=()

while IFS=$'\t' read -r \
  name \
  type \
  size \
  rm \
  tran \
  mounts \
  fstype \
  md_member \
  model \
  serial
do
  [[ -n "${name:-}" ]] || continue
  [[ "${name:0:1}" != "#" ]] || continue

  if [[ "$type" != "disk" ]]; then
    reject "$name" "not a whole disk"
    continue
  fi

  if [[ ! "$size" =~ ^[0-9]+$ ]]; then
    reject "$name" "invalid disk size"
    continue
  fi

  if ((size < MIN_TARGET_BYTES)); then
    reject "$name" "smaller than configured minimum"
    continue
  fi

  if ((size > MAX_TARGET_BYTES)); then
    reject "$name" "larger than configured maximum"
    continue
  fi

  if [[ "$rm" == "1" ]] &&
    ! is_true "$ALLOW_USB_TARGET"; then
    reject "$name" "removable media"
    continue
  fi

  if [[ "$tran" == "usb" ]] &&
    ! is_true "$ALLOW_USB_TARGET"; then
    reject "$name" "USB transport"
    continue
  fi

  if [[ -n "$mounts" && "$mounts" != "-" ]]; then
    reject "$name" "disk or child filesystem is mounted"
    continue
  fi

  if [[ "$md_member" == "1" ]]; then
    reject "$name" "Linux RAID member detected"
    continue
  fi

  if [[ "$fstype" == "linux_raid_member" ]]; then
    reject "$name" "Linux RAID filesystem signature"
    continue
  fi

  candidates+=("$name")
done < <(emit_inventory)

if ((${#candidates[@]} == 0)); then
  die "No safe installation target found"
fi

if is_true "$REQUIRE_SINGLE_CANDIDATE" &&
  ((${#candidates[@]} != 1)); then

  printf '[PX6-OMVAI] Candidate disks:' >&2
  printf ' %s' "${candidates[@]}" >&2
  printf '\n' >&2

  die "Refusing ambiguous installation target"
fi

printf '%s\n' "${candidates[0]}"