#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/hermes-app"
WEB_DIR="$APP_DIR/build/web"
LOG_DIR="$SCRIPT_DIR/hermes-app/logs"
PORT=3003

mkdir -p "$LOG_DIR"

echo "=== Restarting hermes-app web on port $PORT ==="

# Kill existing server on port 3003
if pid=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+'); then
    echo "Killing existing server (PID: $pid)..."
    kill $pid 2>/dev/null || true
    sleep 1
fi

# Ensure web build exists
if [ ! -d "$WEB_DIR" ]; then
    echo "Web build not found, running flutter build..."
    cd "$APP_DIR"
    flutter build web
    cd "$SCRIPT_DIR"
fi

# Start server with access logging
echo "Starting server..."
cd "$WEB_DIR"
nohup python3 -m http.server $PORT >> "$LOG_DIR/app.log" 2>&1 &
SERVER_PID=$!

echo "Server started (PID: $SERVER_PID)"
echo "Logs: $LOG_DIR/app.log"
echo "URL: http://localhost:$PORT"
echo ""
echo "=== Debug logging enabled ==="
echo "View logs: tail -f $LOG_DIR/app.log"