#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/common.sh"
load_config "$ROOT_DIR/config/build.conf"

hash="${PX6_ADMIN_PASSWORD_HASH:-}"
ssh="${PX6_ENABLE_SSH:-}"

[[ "$hash" =~ ^\$6\$[A-Za-z0-9./]{1,16}\$[A-Za-z0-9./]{40,}$ ]] || die "PX6_ADMIN_PASSWORD_HASH is not a valid SHA-512 crypt hash"
[[ "$ssh" == yes || "$ssh" == no ]] || die "PX6_ENABLE_SSH must be yes or no"

out_dir="$ROOT_DIR/$BUILD_DIR/personalization"
mkdir -p "$out_dir"
umask 077

ssh_package=""
if [[ "$ssh" == yes ]]; then
  ssh_package="openssh-server"
fi

sed \
  -e "s|@PX6_ADMIN_PASSWORD_HASH@|$hash|g" \
  -e "s|@PX6_SSH_PACKAGE@|$ssh_package|g" \
  "$ROOT_DIR/preseed/preseed.cfg.in" > "$out_dir/preseed.cfg"

cat > "$out_dir/installer.conf" <<EOF_CONFIG
CONFIG_VERSION=1
ADMIN_USER=admin
ADMIN_PASSWORD_HASH=$hash
ENABLE_SSH=$ssh
EOF_CONFIG

chmod 0600 "$out_dir/preseed.cfg" "$out_dir/installer.conf"

grep -Fq 'passwd/username string admin' "$out_dir/preseed.cfg" || die "Generated preseed does not create admin"
grep -Fq "passwd/user-password-crypted password $hash" "$out_dir/preseed.cfg" || die "Generated preseed is missing the supplied hash"
if grep -Fq '@PX6_' "$out_dir/preseed.cfg"; then
  die "Generated preseed still contains template tokens"
fi

log "Generated personalized installer configuration"