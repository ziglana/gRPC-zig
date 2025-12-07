#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "======================================================================"
echo "gRPC-zig Integration Test Runner"
echo "======================================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Cleanup function
cleanup() {
    if [ ! -z "$SERVER_PID" ]; then
        print_status "Stopping test server (PID: $SERVER_PID)..."
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Step 1: Build the integration test server
print_status "Building integration test server..."
cd "$PROJECT_ROOT"
zig build integration_test || {
    print_error "Build failed!"
    exit 1
}

# Check if executable exists
if [ ! -f "$PROJECT_ROOT/zig-out/bin/grpc-test-server" ]; then
    print_error "Test server executable not found!"
    exit 1
fi

# Step 2: Start the server in background
print_status "Starting test server on port 50052..."
"$PROJECT_ROOT/zig-out/bin/grpc-test-server" > /tmp/grpc_test_server.log 2>&1 &
SERVER_PID=$!

print_status "Server started with PID: $SERVER_PID"

# Wait for server to be ready
print_status "Waiting for server to be ready..."
sleep 2

# Check if server is still running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    print_error "Server failed to start! Check logs:"
    cat /tmp/grpc_test_server.log
    exit 1
fi

print_status "Server is running"

# Step 3: Setup Python environment
print_status "Setting up Python test environment..."
cd "$SCRIPT_DIR"

if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
fi

print_status "Activating virtual environment..."
source venv/bin/activate

print_status "Installing Python dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Step 4: Run Python tests
print_status "Running integration tests..."
echo ""
python3 test_client.py
TEST_RESULT=$?

# Deactivate venv
deactivate

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    print_status "Integration tests completed successfully!"
    exit 0
else
    print_error "Integration tests failed!"
    print_warning "Server logs:"
    cat /tmp/grpc_test_server.log
    exit 1
fi
