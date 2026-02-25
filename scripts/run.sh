#!/bin/bash
# Launch the Claude Expertise system (Phoenix API + SwiftUI menubar app)
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Claude Expertise Launcher ==="

# 1. Start Phoenix API server
echo "[1/3] Starting Phoenix API server on :8645..."
cd "$PROJECT_ROOT/expertise_api"

# Kill existing if running
lsof -ti:8645 2>/dev/null | xargs kill -9 2>/dev/null || true
sleep 1

MIX_ENV=dev mix phx.server &
PHOENIX_PID=$!
echo "  Phoenix PID: $PHOENIX_PID"

# Wait for server to be ready
echo "  Waiting for server..."
for i in $(seq 1 30); do
    if curl -s http://localhost:8645/api/health > /dev/null 2>&1; then
        echo "  Server ready!"
        break
    fi
    sleep 1
done

# 2. Build and run SwiftUI app
echo "[2/3] Building SwiftUI menubar app..."
cd "$PROJECT_ROOT/ExpertiseApp"
swift build 2>&1 | tail -1

echo "[3/3] Launching menubar app..."
.build/debug/ExpertiseApp &
APP_PID=$!
echo "  App PID: $APP_PID"

echo ""
echo "=== Running ==="
echo "  Phoenix API:  http://localhost:8645"
echo "  Search API:   http://localhost:8645/api/search?q=<query>"
echo "  Menubar app:  Look for the purple brain icon in your menubar"
echo ""
echo "Press Ctrl+C to stop all services"

cleanup() {
    echo ""
    echo "Shutting down..."
    kill $APP_PID 2>/dev/null || true
    kill $PHOENIX_PID 2>/dev/null || true
    lsof -ti:8645 2>/dev/null | xargs kill -9 2>/dev/null || true
    echo "Done."
}

trap cleanup EXIT INT TERM
wait
