const std = @import("std");
const GrpcServer = @import("grpc").GrpcServer;

pub fn main(init: std.process.Init) !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    var server = try GrpcServer.init(allocator, init.io, 50051, "secret-key");
    defer server.deinit();

    // Register handlers
    try server.handlers.append(
        allocator,
        .{
            .name = "SayHello",
            .handler_fn = sayHello,
        },
    );

    // Register benchmark handler
    try server.handlers.append(
        allocator,
        .{
            .name = "Benchmark",
            .handler_fn = benchmarkHandler,
        },
    );

    try server.start();
}

fn sayHello(request: []const u8, allocator: std.mem.Allocator, _: std.Io) ![]u8 {
    _ = request;
    return allocator.dupe(u8, "Hello from gRPC!");
}

fn benchmarkHandler(request: []const u8, allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    // Echo the request back with a timestamp for benchmarking
    const response = try std.fmt.allocPrint(allocator, "Echo: {s} (processed at {d})", .{ request, std.Io.Timestamp.now(io, .real).toMilliseconds() });
    return response;
}
