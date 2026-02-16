# Copilot Instructions for gRPC-zig

## Project Overview

This is a gRPC implementation in Zig with HTTP/2 support, compression, authentication, and streaming capabilities.

## Build Instructions

```bash
# Build the project
zig build

# Build and run examples
zig build install

# Run benchmarks (starts server automatically)
zig build benchmark

# Run benchmarks manually (requires server running)
zig build benchmark-manual
```

## Test Instructions

```bash
# Run unit tests
zig build test

# Build integration test server
zig build integration_test

# Run integration tests (requires Python and proto requirements)
cd integration_test && pip3 install --user --break-system-packages -r requirements.txt
./run_tests.sh
```

## CI/CD Setup

This project uses a simple Zig-based build system:
- **Build**: `zig build` compiles all executables
- **Test**: `zig build test` runs the test suite
- **Integration Tests**: Python-based tests in `integration_test/` directory

## Development Workflow

1. **Building**: Run `zig build` after any code changes
2. **Testing**: Run `zig build test` to verify changes
3. **Benchmarking**: Use `zig build benchmark` to measure performance

## Key Files

- `build.zig` - Main build configuration
- `src/server.zig` - gRPC server implementation
- `src/client.zig` - gRPC client implementation
- `src/transport.zig` - Transport layer
- `src/http2/` - HTTP/2 protocol implementation
- `examples/` - Example applications
- `integration_test/` - Integration tests

## Important Notes

- This is a Zig project requiring Zig 0.13+ or compatible version
- The build system uses `spice` as a dependency (auto-fetched)
- Integration tests require Python 3 with `grpcio` and `grpcio-tools` packages
