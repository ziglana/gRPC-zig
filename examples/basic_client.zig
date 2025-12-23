const std = @import("std");
const GrpcClient = @import("grpcclient").GrpcClient;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try GrpcClient.init(allocator, "localhost", 50051);
    defer client.deinit();

    // Set authentication
    try client.setAuth("secret-key");

    // Make a simple call
    const response = try client.call("SayHello", "World", .none);
    defer allocator.free(response);

    std.debug.print("Response: {s}\n", .{response});
}
