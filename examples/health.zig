const std = @import("std");
const health = @import("features/health.zig");

pub fn main() !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    var health_checker = health.HealthCheck.init(allocator);
    defer health_checker.deinit();

    // Register services and set their status
    try health_checker.setStatus("auth.service", .SERVING);
    try health_checker.setStatus("database.service", .NOT_SERVING);
    try health_checker.setStatus("cache.service", .SERVING);

    // Check service health
    const auth_status = try health_checker.check("auth.service");
    const db_status = try health_checker.check("database.service");

    std.debug.print("Auth service status: {}\n", .{auth_status});
    std.debug.print("Database service status: {}\n", .{db_status});

    // Try to check non-existent service
    health_checker.check("unknown.service") catch |err| {
        std.debug.print("Expected error for unknown service: {}\n", .{err});
    };
}
