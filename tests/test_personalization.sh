#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PX6_ADMIN_PASSWORD_HASH='$6$testsalt$uP0P2G1N7rw7cGL6KxZUPK2gKUaARbFNHvI6WxwD8Y1NlrX4Kvlv1XNG37pTtSdtGxVl2cwwGx8TK1FPmD5YH0'
export PX6_ENABLE_SSH=yes
"$ROOT_DIR/scripts/generate_installer_config.sh"
conf="$ROOT_DIR/build/personalization/installer.conf"
preseed="$ROOT_DIR/build/personalization/preseed.cfg"
grep -Fq 'ADMIN_USER=admin' "$conf"
grep -Fq 'ENABLE_SSH=yes' "$conf"
grep -Fq 'openssh-server' "$preseed"
grep -Fq "$PX6_ADMIN_PASSWORD_HASH" "$preseed"
! grep -Fq '@PX6_' "$preseed"
! grep -Fq 'px6admin' "$preseed"
printf '%s\n' 'PASS: personalized installer configuration is valid'