#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
set -xe

yum update -y
mkdir /portfolio

sudo systemctl start nginx

aws s3 cp s3://342989859526.tfstate/portfolio-app.tar.gz /portfolio/
tar -xzf /portfolio/portfolio-app.tar.gz -C /portfolio


sudo tee /portfolio-compose.yml >/dev/null <<'COMPOSE'
services:
  portfolio:
    build: /portfolio/
    container_name: portfolio
    ports:
      - "3000:3000"
    restart: unless-stopped
COMPOSE

docker compose -p portfolio -f /portfolio-compose.yml up -d --build