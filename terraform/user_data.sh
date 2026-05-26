#!/usr/bin/env bash
# Cloud-init / user_data script: bootstrap Docker + clone repo + start the stack.
# Logs land in /var/log/user-data.log.
set -euxo pipefail
exec > >(tee -a /var/log/user-data.log) 2>&1

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg git

# Docker Engine + Compose plugin (official repo, pinned to stable channel).
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker ubuntu || true

# Clone the repo and start the stack.
install -d -o ubuntu -g ubuntu /opt/monitoring_stack
sudo -u ubuntu git clone --depth=1 --branch '${repo_ref}' '${repo_url}' /opt/monitoring_stack

cd /opt/monitoring_stack
cp -n .env.example .env || true

# Best-effort bring-up; we don't fail user_data if the first `up` is slow.
docker compose -f compose/docker-compose.yml up -d --wait || \
  docker compose -f compose/docker-compose.yml up -d

# Install a systemd unit so the stack restarts on reboot.
cat >/etc/systemd/system/monitoring-stack.service <<'UNIT'
[Unit]
Description=Monitoring Stack (docker compose)
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/monitoring_stack
ExecStart=/usr/bin/docker compose -f compose/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose -f compose/docker-compose.yml down

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable monitoring-stack.service

echo "user_data complete"
