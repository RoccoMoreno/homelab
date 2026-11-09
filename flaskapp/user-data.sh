#!/bin/bash

# 1. Install Docker
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

#2. Let ubuntu user run docker
usermod -aG docker ubuntu

#3. Go to ubuntu's home folder and get the repo
cd /home/ubuntu/
git clone https://github.com/RoccoMoreno/homelab.git

#4. Go into the flaskapp folder and create the .env
cd /home/ubuntu/homelab/flaskapp/
echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" > .env
chmod 600 .env
chown -R ubuntu:ubuntu /home/ubuntu/homelab/

# 5.Bring the stack up
docker compose up -d --build
