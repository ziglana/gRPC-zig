# CLAUDE.md - Project Context for AI Assistants

## Project Name
gRPC-zig

## Project Purpose
A gRPC implementation in Zig featuring HTTP/2 transport, authentication, compression, health checks, and streaming capabilities.

## Language & Build
- **Language**: Zig
- **Build Tool**: zig build
- **Main Dependencies**: spice (HTTP/2 framework)

## Source Files

### Core
- `/tmp/claudev-pr-64669/src/client.zig` - gRPC client with transport, compression, auth
- `/tmp/claudev-pr-64669/src/server.zig` - gRPC server with handlers, health checks
- `/tmp/claudev-pr-64669/src/transport.zig` - Transport layer abstraction
- `/tmp/claudev-pr-64669/src/benchmark.zig` - Benchmarking tool with latency stats
- `/tmp/claudev-pr-64669/src/tests.zig` - Test suite

### Features (`src/features/`)
- `auth.zig` - JWT token generation and verification
- `compression.zig` - gzip/deflate compression
- `health.zig` - HealthCheck service with SERVING/NOT_SERVING states
- `streaming.zig` - MessageStream for bidirectional streaming

### HTTP/2 (`src/http2/`)
- `connection.zig` - HTTP/2 connection management
- `frame.zig` - HTTP/2 frame types (HEADERS, DATA, SETTINGS, etc.)
- `hpack.zig` - HPACK header encoding/decoding (Encoder/Decoder)
- `stream.zig` - HTTP/2 stream state management

### Protocol (`src/proto/`)
- `service.zig` - HelloRequest/HelloResponse protobuf structures

### Examples (`examples/`)
- `basic_server.zig`, `basic_client.zig` - Basic usage
- `auth.zig` - JWT authentication example
- `compression.zig` - Compression example
- `health.zig` - Health check example
- `streaming.zig` - Streaming example
- `http2_transport.zig` - HTTP/2 transport example

## Key APIs

### GrpcServer
```zig
// Init with port and secret key
pub fn init(allocator: std.mem.Allocator, port: u16, secret_key: []const u8) !GrpcServer
// Register handlers
pub fn handlers: std.ArrayList(Handler)
// Start server
pub fn start(self: *GrpcServer) !void
```

### GrpcClient
```zig
// Init with host and port
pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) !GrpcClient
// Set authentication
pub fn setAuth(self: *GrpcClient, secret_key: []const u8) !void
// Make RPC call
pub fn call(self: *GrpcClient, method: []const u8, request: []const u8, compression_alg: compression.Compression.Algorithm) ![]u8
// Health check
pub fn checkHealth(self: *GrpcClient, service: []const u8) !health.HealthStatus
```

### Compression
```zig
pub fn compress(data: []const u8, algorithm: Algorithm) ![]u8
pub fn decompress(data: []const u8, algorithm: Algorithm) ![]u8
```

### Auth
```zig
pub fn generateToken(self: *Auth, subject: []const u8, expires_in: i64) ![]u8
pub fn verifyToken(self: *Auth, token: []const u8) !void
```

### Health
```zig
pub fn setStatus(self: *HealthCheck, service: []const u8, status: HealthStatus) !void
pub fn check(self: *HealthCheck, service: []const u8) !HealthStatus
```

## Build Commands
```bash
zig build           # Build all targets
zig build test      # Run tests
zig build benchmark # Run benchmarks
```

## Important Conventions
- Use `std.heap.GeneralPurposeAllocator(.{}){}` for allocator
- Always defer `.deinit()` and `allocator.free()`
- Use `try` for error propagation
- Keep files under 200 lines
- HPACK Encoder/Decoder for header compression
- Stream states: IDLE, RESERVED_LOCAL, RESERVED_REMOTE, OPEN, HALF_CLOSED_LOCAL, HALF_CLOSED_REMOTE, CLOSED
