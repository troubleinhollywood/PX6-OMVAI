#!/bin/sh
set -eu
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export LANG=C.UTF-8

apt-get update
apt-get install -y --no-install-recommends systemd-resolved psmisc gnupg wget ca-certificates
systemctl enable systemd-resolved.service

wget -qO- https://packages.openmediavault.org/public/archive.key |
  gpg --dearmor --yes -o /usr/share/keyrings/openmediavault-archive-keyring.gpg

cat >/etc/apt/sources.list.d/openmediavault.list <<'REPO'
deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] https://packages.openmediavault.org/public synchrony main
REPO

apt-get update
apt-get --yes --auto-remove --show-upgraded   --allow-downgrades --allow-change-held-packages   --no-install-recommends   -o DPkg::Options::="--force-confdef"   -o DPkg::Options::="--force-confold"   install openmediavault

omv-confdbadm populate
omv-salt deploy run systemd-networkd || true
systemctl enable ssh.service || true
printf '%s\n' "PX6 install complete $(date -u +%FT%TZ)" >/root/PX6-INSTALL-COMPLETE.txt
