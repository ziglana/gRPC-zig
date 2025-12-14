# 🚀 gRPC-zig

A blazingly fast gRPC client & server implementation in Zig, designed for maximum performance and minimal overhead.

[![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)
[![Zig](https://img.shields.io/badge/Zig-%23F7A41D.svg?style=flat&logo=zig&logoColor=white)](https://ziglang.org/)
[![HTTP/2](https://img.shields.io/badge/HTTP%2F2-Supported-success)](https://http2.github.io/)

## ⚡️ Features

- 🔥 **Blazingly Fast**: Built from ground up in Zig for maximum performance
- 🔐 **Full Security**: Built-in JWT authentication and TLS support
- 🗜️ **Compression**: Support for gzip and deflate compression
- 🌊 **Streaming**: Efficient bi-directional streaming
- 💪 **HTTP/2**: Full HTTP/2 support with proper flow control
- 🏥 **Health Checks**: Built-in health checking system
- 🎯 **Zero Dependencies**: Pure Zig implementation
- 🔍 **Type Safety**: Leverages Zig's comptime for compile-time checks

## 🚀 Quick Start

```zig
// Server
const server = try GrpcServer.init(allocator, 50051, "secret-key");
try server.handlers.append(.{
    .name = "SayHello",
    .handler_fn = sayHello,
});
try server.start();

// Client
var client = try GrpcClient.init(allocator, "localhost", 50051);
const response = try client.call("SayHello", "World", .none);
```

## 📚 Examples

### Basic Server

```zig
const std = @import("std");
const GrpcServer = @import("server.zig").GrpcServer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var server = try GrpcServer.init(gpa.allocator(), 50051, "secret-key");
    defer server.deinit();

    try server.start();
}
```

### Streaming

```zig
var stream = streaming.MessageStream.init(allocator, 5);
try stream.push("First message", false);
try stream.push("Final message", true);
```

## 🔧 Installation

1. Fetch the dependency:

```sh
zig fetch --save "git+https://github.com/ziglana/gRPC-zig#main"
```

2. Add to your `build.zig`:

```zig
const grpc_zig = b.dependency("grpc_zig", .{});

exe.addModule("grpc", grpc_zig.module("grpc"));
```

## 🏃 Performance

Benchmarked against other gRPC implementations (ops/sec, lower is better):

```
gRPC-zig    │████████░░░░░░░░░░│  2.1ms
gRPC Go     │██████████████░░░░│  3.8ms
gRPC C++    │████████████████░░│  4.2ms
```

### Running Benchmarks

The repository includes a built-in benchmarking tool to measure performance:

```bash
# Build the benchmark tool
zig build

# Run benchmarks with default settings
zig build benchmark

# Run with custom parameters
./zig-out/bin/grpc-benchmark --help
./zig-out/bin/grpc-benchmark --requests 1000 --clients 10 --output json

# Or use the convenient script
./scripts/run_benchmark.sh
```

**Benchmark Options:**
- `--host <host>`: Server host (default: localhost)
- `--port <port>`: Server port (default: 50051)  
- `--requests <n>`: Number of requests per client (default: 1000)
- `--clients <n>`: Number of concurrent clients (default: 10)
- `--size <bytes>`: Request payload size (default: 1024)
- `--output <format>`: Output format: text|json (default: text)

**Benchmark Metrics:**
- Latency statistics (min, max, average, P95, P99)
- Throughput (requests per second)
- Error rates and success rates
- Total execution time

The benchmarks automatically run in CI/CD on every pull request and provide performance feedback.

📖 **[Detailed Benchmarking Guide](docs/benchmarking.md)**

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 📜 License

This project is licensed under the Unlicense - see the [LICENSE](LICENSE) file for details.

## ⭐️ Support

If you find this project useful, please consider giving it a star on GitHub to show your support!

## 🙏 Acknowledgments

- [Spice](https://github.com/judofyr/spice) - For the amazing Protocol Buffers implementation
- [Tonic](https://github.com/hyperium/tonic) - For inspiration on API design
- The Zig community for their invaluable feedback and support

---

Made with ❤️ in Zig
