const std = @import("std");
const transport = @import("transport.zig");
const http2 = struct {
    pub const connection = @import("http2/connection.zig");
    pub const frame = @import("http2/frame.zig");
};

pub fn main() !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    // Create a TCP connection (simplified for example)
    const stream = try std.net.tcpConnectToHost(allocator, "localhost", 50051);
    defer stream.close();

    // Initialize transport with HTTP/2
    var trans = try transport.Transport.init(allocator, stream);
    defer trans.deinit();

    // Send a message
    const message = "Hello over HTTP/2";
    try trans.writeMessage(message);

    // Read response
    const response = try trans.readMessage();
    defer allocator.free(response);

    std.debug.print("Received: {s}\n", .{response});
}
