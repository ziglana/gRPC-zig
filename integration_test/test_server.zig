const std = @import("std");
const GrpcServer = @import("grpc").GrpcServer;
const proto = @import("proto.zig");
const spice = @import("spice");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const port = 50052; // Use different port to avoid conflicts
    var server = try GrpcServer.init(allocator, port, "test-secret-key");
    defer server.deinit();

    std.log.info("Integration test server starting on port {d}", .{port});

    // Register test handlers
    try server.handlers.append(
        allocator,
        .{
            .name = "Echo",
            .handler_fn = echoHandler,
        },
    );

    try server.handlers.append(
        allocator,
        .{
            .name = "CompressedEcho",
            .handler_fn = compressedEchoHandler,
        },
    );

    try server.handlers.append(
        allocator,
        .{
            .name = "HealthCheck",
            .handler_fn = healthCheckHandler,
        },
    );

    try server.handlers.append(
        allocator,
        .{
            .name = "SecureEcho",
            .handler_fn = secureEchoHandler,
        },
    );

    std.log.info("Test server ready with handlers: Echo, CompressedEcho, HealthCheck, SecureEcho", .{});

    try server.start();
}

fn echoHandler(request: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // For now, just echo back the request with server info
    // TODO: Implement proper protobuf decode/encode when Spice API is stable
    const timestamp = std.time.timestamp();
    const response = try std.fmt.allocPrint(
        allocator,
        "Echo: {s} | Server: gRPC-zig | Time: {d}",
        .{ request, timestamp },
    );
    return response;
}

fn compressedEchoHandler(request: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // Similar to echo but the server will compress the response
    const timestamp = std.time.timestamp();
    const response = try std.fmt.allocPrint(
        allocator,
        "CompressedEcho: {s} | Server: gRPC-zig | Time: {d}",
        .{ request, timestamp },
    );
    return response;
}

fn healthCheckHandler(request: []const u8, allocator: std.mem.Allocator) ![]u8 {
    _ = request;
    // Return a simple health status
    const response = try allocator.dupe(u8, "SERVING");
    return response;
}

fn secureEchoHandler(request: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // This handler expects authentication (will be handled by the server layer)
    const timestamp = std.time.timestamp();
    const response = try std.fmt.allocPrint(
        allocator,
        "SecureEcho: {s} | Server: gRPC-zig (authenticated) | Time: {d}",
        .{ request, timestamp },
    );
    return response;
}
