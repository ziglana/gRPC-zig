const std = @import("std");
const GrpcClient = @import("grpcclient").GrpcClient;

pub fn main(init: std.process.Init) !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    var client = try GrpcClient.init(allocator, init.io, "localhost", 50051);
    defer client.deinit();

    // Set authentication
    try client.setAuth("secret-key");

    // Make a simple call
    const response = try client.call("SayHello", "World", .none);
    defer allocator.free(response);

    std.debug.print("Response: {s}\n", .{response});
}
