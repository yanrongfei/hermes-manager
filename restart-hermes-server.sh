#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/hermes-server"
DATA_DIR="/vol1/1000/nas1/docker/hermes-server"

echo "=== Restarting hermes-server ==="

cd "$SERVER_DIR"

echo "[1/4] Stopping container..."
docker compose -f docker-compose.prod.yml down

read -p "Clear DB? [y/N] " confirm
if [[ "$confirm" =~ ^[yY]$ ]]; then
    echo "[2/4] Clearing DB..."
    rm -f "$DATA_DIR/data/hermes.db"
    echo "    DB cleared"
else
    echo "[2/4] Skipping DB clear"
fi

echo "[3/4] Building..."
docker compose -f docker-compose.prod.yml build

echo "[4/4] Starting..."
docker compose -f docker-compose.prod.yml up -d

echo "=== Done ==="
docker compose -f docker-compose.prod.yml ps