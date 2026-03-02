#!/bin/bash
# Launch the Claude Expertise system (DB init + Phoenix API + SwiftUI menubar app)
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Claude Expertise Launcher ==="

# 0. Initialize/migrate database
echo "[0/4] Initializing database..."
cd "$PROJECT_ROOT"
python3 scripts/database.py init 2>&1 | sed 's/^/  /'

# 1. Start Phoenix API server
echo "[1/4] Starting Phoenix API server on :8645..."
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

# 2. Auto-discover resources in database
echo "[2/4] Discovering resources in posts..."
cd "$PROJECT_ROOT"
python3 scripts/database.py discover 2>&1 | sed 's/^/  /' || true

# 3. Build and run SwiftUI app
echo "[3/4] Building SwiftUI menubar app..."
cd "$PROJECT_ROOT/ExpertiseApp"
swift build 2>&1 | tail -1

echo "[4/4] Launching menubar app..."
.build/debug/ExpertiseApp &
APP_PID=$!
echo "  App PID: $APP_PID"

echo ""
echo "=== Running ==="
echo "  Phoenix API:  http://localhost:8645"
echo "  Search API:   http://localhost:8645/api/search?q=<query>"
echo "  Ask API:      http://localhost:8645/api/ask?q=<question>"
echo "  Stats API:    http://localhost:8645/api/stats"
echo "  Taxonomy:     http://localhost:8645/api/taxonomy"
echo "  Resources:    http://localhost:8645/api/resources"
echo "  Ingest:       POST http://localhost:8645/api/ingest"
echo "  Menubar app:  Look for the brain icon in your menubar"
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
