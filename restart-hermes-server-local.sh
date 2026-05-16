#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/hermes-server"
LOG_DIR="$SCRIPT_DIR/hermes-server/logs"

mkdir -p "$LOG_DIR"

echo "=== Restarting hermes-server (local debug mode) ==="

# Stop Docker container
echo "[1/4] Stopping Docker container..."
docker stop hermes-server 2>/dev/null || true
docker rm hermes-server 2>/dev/null || true

# Stop any existing local process on port 3002
echo "[2/4] Checking port 3002..."
if pid=$(lsof -ti:3002 2>/dev/null); then
    echo "    Killing PID $pid on port 3002..."
    kill $pid 2>/dev/null || true
    sleep 1
fi

# Activate venv and start
echo "[3/4] Starting server with DEBUG=true..."
cd "$SERVER_DIR"
source .venv/bin/activate

export DEBUG=true
export LOG_LEVEL=DEBUG

nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 3002 > "$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!

echo "    Server started (PID: $SERVER_PID)"
echo "    Logs: $LOG_DIR/server.log"

sleep 2

# Verify
if curl -s http://127.0.0.1:3002/health > /dev/null 2>&1; then
    echo "=== Server is running ==="
else
    echo "=== Server may have failed to start. Check $LOG_DIR/server.log ==="
    cat "$LOG_DIR/server.log" | tail -20
fi