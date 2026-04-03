#!/usr/bin/env bash
# Integration test runner for ohr
# Builds, starts server, runs pytest, and cleans up.

set -euo pipefail

PORT=11436
TOKEN="test-integration-token"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Building release binary ==="
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -1

BINARY="$PROJECT_DIR/.build/release/ohr"
if [ ! -x "$BINARY" ]; then
    echo "error: missing $BINARY"
    exit 1
fi

echo "=== Starting ohr server on port $PORT ==="
$BINARY --serve --port $PORT --token $TOKEN --debug &
SERVER_PID=$!

cleanup() {
    echo "=== Stopping server (PID $SERVER_PID) ==="
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true
}
trap cleanup EXIT

# Wait for server to be ready
for i in $(seq 1 30); do
    if curl -s "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo "=== Server ready ==="
        break
    fi
    if [ $i -eq 30 ]; then
        echo "error: server failed to start within 30s"
        exit 1
    fi
    sleep 1
done

echo "=== Running integration tests ==="
OHR_TEST_PORT=$PORT OHR_TEST_TOKEN=$TOKEN OHR_TEST_BINARY=$BINARY \
    python3 -m pytest "$SCRIPT_DIR" -v --tb=short "$@"

echo "=== Done ==="
