#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
set -xe

yum update -y

sudo systemctl start nginx
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin 342989859526.dkr.ecr.us-east-1.amazonaws.com/alxphelps/portfolio

sudo tee /portfolio-compose.yml >/dev/null <<'COMPOSE'
services:
  portfolio:
    image: 342989859526.dkr.ecr.us-east-1.amazonaws.com/alxphelps/portfolio:latest
    container_name: portfolio
    ports:
      - "3000:3000"
    restart: unless-stopped
COMPOSE

docker compose -p portfolio -f /portfolio-compose.yml up -d --build
