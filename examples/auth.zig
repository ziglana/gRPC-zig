const std = @import("std");
const auth = @import("features/auth.zig");

pub fn main(init: std.process.Init) !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    var auth_handler = auth.Auth.init(allocator, init.io, "my-secret-key");

    // Generate a token
    const token = try auth_handler.generateToken("user123", 3600);
    defer allocator.free(token);

    std.debug.print("Generated token: {s}\n", .{token});

    // Verify the token
    try auth_handler.verifyToken(token);
    std.debug.print("Token verified successfully\n", .{});

    // Try to verify an invalid token
    auth_handler.verifyToken("invalid.token.here") catch |err| {
        std.debug.print("Expected error: {}\n", .{err});
    };
}
