# mTLS and Custom Certificate Support Specification

## Overview
Add support for mTLS (mutual TLS) and custom certificates to enable secure gRPC communications with certificate-based authentication.

## Requirements

### Server-side TLS
- Load server certificate from PEM file
- Load server private key from PEM file
- Optional: Client CA certificate for mTLS client verification
- Support custom certificate paths

### Client-side TLS
- Load trusted CA certificate for server verification
- Load client certificate for mTLS
- Load client private key
- Support custom certificate paths
- Option to skip server certificate verification (insecure mode for development)

### API Design

#### Server Configuration
```zig
pub const TlsConfig = struct {
    cert_file: []const u8,
    key_file: []const u8,
    client_ca_file: ?[]const u8 = null, // for mTLS
};

// Server init with TLS:
GrpcServer.init(allocator, port, secret_key, tls_config);
```

#### Client Configuration
```zig
pub const ClientTlsConfig = struct {
    ca_file: ?[]const u8 = null,
    cert_file: ?[]const u8 = null,
    key_file: ?[]const u8 = null,
    skip_verify: bool = false,
};

// Client init with TLS:
GrpcClient.init(allocator, host, port, tls_config);
```

## Implementation Plan

1. Create `src/tls.zig` - TLS configuration and utilities
2. Modify `src/transport.zig` - Add TLS stream wrapper
3. Modify `src/server.zig` - Add TLS support to server initialization
4. Modify `src/client.zig` - Add TLS support to client initialization
5. Update examples with TLS usage
6. Build and test

## Files to Modify
- `src/server.zig` - Add TLS config parameter
- `src/client.zig` - Add TLS config parameter
- `src/transport.zig` - Add TLS stream support

## Files to Create
- `src/tls.zig` - TLS configuration module
