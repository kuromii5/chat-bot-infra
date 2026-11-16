#!/usr/bin/env bash
# Installs Docker Engine from the Ubuntu repositories. Must run as root.
#
#   sudo ./scripts/install-docker.sh
#
# After it finishes, log out and back in (or run `newgrp docker`) so the
# current user can talk to the Docker socket without sudo.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script as root: sudo $0" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-${TARGET_USER:-alex}}"

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Unknown target user: $TARGET_USER" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y docker.io
systemctl enable --now docker

if ! id -nG "$TARGET_USER" | grep -qw docker; then
  usermod -aG docker "$TARGET_USER"
fi

echo
echo "Docker installed:"
docker version --format 'client={{.Client.Version}} server={{.Server.Version}}'

echo
echo "User '$TARGET_USER' added to the docker group."
echo "Log out and back in (or run 'newgrp docker') before using docker without sudo."
