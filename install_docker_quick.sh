#!/bin/bash
# Docker install - Quick mode
# Usage: curl -fsSL <url>/install_docker_quick.sh | sudo bash
# Compatible: Ubuntu, Debian

set -euo pipefail

command -v docker &>/dev/null && { echo "[SKIP] Docker already installed: $(docker --version)"; exit 0; }

source /etc/os-release

case "$ID" in
    ubuntu|debian) ;;
    *) echo "[ERROR] Unsupported distro: $ID"; exit 1 ;;
esac

CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
[[ -z "$CODENAME" ]] && { echo "[ERROR] Cannot determine distro codename"; exit 1; }

apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} ${CODENAME} stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

echo "[OK] $(docker --version)"
echo "[OK] $(docker compose version)"
