# gRPC-zig Integration Tests

This directory contains integration tests for validating the gRPC-zig server implementation using a Python client.

## Overview

The integration test suite validates that the Zig gRPC server correctly implements the gRPC protocol by:

1. Starting a test server written in Zig
2. Connecting from a Python client
3. Testing various gRPC features:
   - Basic RPC calls (Echo)
   - Compression (CompressedEcho)
   - Health checking (HealthCheck)
   - Authentication (SecureEcho)

## Files

- `test_service.proto` - Protocol buffer service definition
- `proto.zig` - Zig protobuf message structures
- `test_server.zig` - Integration test server implementation
- `test_client.py` - Python test client
- `requirements.txt` - Python dependencies
- `run_tests.sh` - Automated test runner script

## Prerequisites

- Zig 0.15.2
- Python 3.8+
- pip (Python package manager)

## Running the Tests

### Quick Start (Automated)

Run the complete test suite automatically:

```bash
./run_tests.sh
```

This script will:
1. Build the test server
2. Start the server on port 50052
3. Set up a Python virtual environment
4. Install dependencies
5. Run the integration tests
6. Clean up and report results

### Manual Testing

If you prefer to run steps manually:

1. **Build the test server:**
   ```bash
   cd ..
   zig build integration_test
   ```

2. **Start the server in one terminal:**
   ```bash
   ./zig-out/bin/grpc-test-server
   ```

3. **Run the Python tests in another terminal:**
   ```bash
   cd integration_test
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   python3 test_client.py
   deactivate
   ```

## Test Coverage

The integration tests validate:

### 1. Echo Handler
- Tests basic unary RPC calls
- Validates request/response flow
- Ensures message delivery

### 2. CompressedEcho Handler
- Tests compression support
- Validates gzip compression on responses
- Ensures data integrity with compression

### 3. HealthCheck Handler
- Tests health checking protocol
- Validates service status reporting
- Ensures availability monitoring

### 4. SecureEcho Handler
- Tests authentication integration
- Validates secure RPC calls
- (Note: Full auth validation requires additional setup)

## Server Configuration

The test server runs with the following configuration:

- **Port:** 50052 (different from default 50051 to avoid conflicts)
- **Host:** localhost (127.0.0.1)
- **Secret Key:** "test-secret-key"
- **Features:** All gRPC features enabled (compression, auth, streaming, health)

## Troubleshooting

### Server fails to start

- Check if port 50052 is already in use:
  ```bash
  lsof -i :50052
  ```
- View server logs:
  ```bash
  cat /tmp/grpc_test_server.log
  ```

### Python tests fail

- Ensure Python 3.8+ is installed
- Check that the server is running
- Verify virtual environment activation
- Reinstall dependencies:
  ```bash
  pip install -r requirements.txt --force-reinstall
  ```

### Connection timeout

- The server may take a few seconds to start
- Increase the sleep delay in `run_tests.sh`
- Check firewall settings

## Extending the Tests

To add new test cases:

1. Add the RPC method to `test_service.proto`
2. Update `proto.zig` with new message structures
3. Add handler to `test_server.zig`
4. Add test case to `test_client.py`

## Protocol Details

The test client uses a simplified HTTP/2 implementation for testing purposes. For production use, proper gRPC client libraries should be used with the generated protobuf code.

## Next Steps

- Generate full Python gRPC stubs using grpcio-tools
- Add streaming RPC tests
- Add bidirectional streaming tests
- Add metadata/header validation
- Add TLS/SSL testing
- Add load testing scenarios
