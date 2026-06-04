const std = @import("std");
const compression = @import("features/compression.zig");

pub fn main() !void {
    var safe_allocator = std.heap.SafeAllocator.init(init.gpa, .{});
    defer _ = safe_allocator.deinit();
    const allocator = safe_allocator.allocator();

    var comp = compression.Compression.init(allocator);
    const data = "Hello, this is some test data for compression!";

    // Try different compression algorithms
    const compressed_gzip = try comp.compress(data, .gzip);
    defer allocator.free(compressed_gzip);

    const compressed_deflate = try comp.compress(data, .deflate);
    defer allocator.free(compressed_deflate);

    // Decompress and verify
    const decompressed_gzip = try comp.decompress(compressed_gzip, .gzip);
    defer allocator.free(decompressed_gzip);

    const decompressed_deflate = try comp.decompress(compressed_deflate, .deflate);
    defer allocator.free(decompressed_deflate);

    std.debug.print("Original size: {}\n", .{data.len});
    std.debug.print("Gzip size: {}\n", .{compressed_gzip.len});
    std.debug.print("Deflate size: {}\n", .{compressed_deflate.len});
}
