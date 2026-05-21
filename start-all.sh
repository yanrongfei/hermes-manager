#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Starting Hermes Manager Services ==="
echo ""

# Start server
echo ">>> [1/2] Starting hermes-server..."
bash "$SCRIPT_DIR/restart-hermes-server-local.sh"
echo ""

# Start app
echo ">>> [2/2] Starting hermes-app..."
bash "$SCRIPT_DIR/restart-hermes-app.sh"
echo ""

echo "=== All services started ==="
echo "  Server: http://localhost:3002"
echo "  App:    http://localhost:3003"
echo ""
echo "View logs:"
echo "  Server: tail -f hermes-server/logs/server.log"
echo "  App:    tail -f hermes-app/logs/app.log"