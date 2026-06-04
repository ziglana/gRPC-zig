const std = @import("std");
const streaming = @import("features/streaming.zig");

pub fn main() !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    // Create a message stream with buffer size of 5
    var stream = streaming.MessageStream.init(allocator, 5);
    defer stream.deinit();

    // Push some messages
    try stream.push("First message", false);
    try stream.push("Second message", false);
    try stream.push("Final message", true);

    // Read messages
    while (stream.pop()) |msg| {
        std.debug.print("Message: {s}, End: {}\n", .{ msg.data, msg.is_end });
        allocator.free(msg.data);
    }
}
