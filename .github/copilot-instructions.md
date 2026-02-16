# gRPC-zig Copilot Instructions

## Project Overview
This is a gRPC implementation in Zig with HTTP/2 support, featuring client/server architecture, compression, authentication, health checks, and streaming capabilities.

## Key Technologies
- **Language**: Zig
- **Build System**: Zig build (build.zig)
- **Dependency**: spice (HTTP/2 framework)
- **Protocol**: gRPC over HTTP/2

## Project Structure
```
src/
├── client.zig          # gRPC client implementation
├── server.zig          # gRPC server implementation
├── transport.zig       # Transport layer
├── benchmark.zig       # Benchmarking tool
├── tests.zig           # Test suite
├── features/
│   ├── auth.zig        # Authentication (JWT tokens)
│   ├── compression.zig # gzip/deflate compression
│   ├── health.zig      # Health check service
│   └── streaming.zig   # Message streaming
├── http2/
│   ├── connection.zig  # HTTP/2 connection
│   ├── frame.zig       # HTTP/2 frames
│   ├── hpack.zig       # HPACK header compression
│   └── stream.zig      # HTTP/2 streams
└── proto/
    └── service.zig     # Protocol buffer services

examples/
├── basic_server.zig    # Basic server example
├── basic_client.zig    # Basic client example
├── auth.zig            # Authentication example
├── compression.zig     # Compression example
├── health.zig          # Health check example
├── streaming.zig       # Streaming example
└── http2_transport.zig # HTTP/2 transport example
```

## Build Commands
- `zig build` - Build all executables
- `zig build test` - Run tests
- `zig build benchmark` - Run benchmarks
- `zig build install` - Install artifacts

## Important Patterns

### Server Implementation
```zig
var server = try GrpcServer.init(allocator, port, secret_key);
try server.handlers.append(.{ .name = "MethodName", .handler_fn = handlerFn });
try server.start();
```

### Client Implementation
```zig
var client = try GrpcClient.init(allocator, host, port);
try client.setAuth(secret_key);
const response = try client.call("MethodName", request, .none);
```

### Features
- Authentication uses JWT tokens with HS256
- Compression supports gzip and deflate
- Health checks follow grpc.health.v1.Health protocol
- Streaming uses MessageStream with configurable buffer size

## Development Guidelines
- Use std.heap.GeneralPurposeAllocator for memory management
- Always defer cleanup (.deinit(), allocator.free())
- Follow Zig error handling patterns (try/catch)
- Keep files under 200 lines, split large implementations
- HPACK Encoder/Decoder for header compression
- Stream states: IDLE, RESERVED_LOCAL, RESERVED_REMOTE, OPEN, HALF_CLOSED_LOCAL, HALF_CLOSED_REMOTE, CLOSED
