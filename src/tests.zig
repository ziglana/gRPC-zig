const std = @import("std");
const testing = std.testing;
const proto = @import("proto/service.zig");
const spice = @import("spice");
const benchmark = @import("benchmark.zig");

// TODO: Update these tests for the new Spice API
// test "HelloRequest encode/decode" {
//     const request = proto.HelloRequest{ .name = "test" };
//     var buf: [1024]u8 = undefined;
//     var writer = spice.ProtoWriter.init(&buf);
//     try request.encode(&writer);
//
//     var reader = spice.ProtoReader.init(buf[0..writer.pos]);
//     const decoded = try proto.HelloRequest.decode(&reader);
//     try testing.expectEqualStrings("test", decoded.name);
// }

// TODO: Update these tests for the new Spice API
// test "HelloResponse encode/decode" {
//     const response = proto.HelloResponse{ .message = "Hello, test!" };
//     var buf: [1024]u8 = undefined;
//     var writer = spice.ProtoWriter.init(&buf);
//     try response.encode(&writer);
//
//     var reader = spice.ProtoReader.init(buf[0..writer.pos]);
//     const decoded = try proto.HelloResponse.decode(&reader);
//     try testing.expectEqualStrings("Hello, test!", decoded.message);
// }

test "benchmark handler" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const request = "test_request";
    const response = try benchmark.benchmarkHandler(request, allocator);
    defer allocator.free(response);

    // Verify response contains the request
    try testing.expect(std.mem.indexOf(u8, response, request) != null);
    // Verify response contains timestamp
    try testing.expect(std.mem.indexOf(u8, response, "processed at") != null);
}

test "compression - gzip" {
    const compression = @import("features/compression.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = compression.Compression.init(allocator);

    // Test data
    const original = "Hello, World! This is a test of gzip compression. " ** 10;

    // Compress
    const compressed = try comp.compress(original, .gzip);
    defer allocator.free(compressed);

    // Compressed should be smaller than original
    try testing.expect(compressed.len < original.len);

    // Decompress
    const decompressed = try comp.decompress(compressed, .gzip);
    defer allocator.free(decompressed);

    // Should match original
    try testing.expectEqualStrings(original, decompressed);
}

test "compression - deflate" {
    const compression = @import("features/compression.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = compression.Compression.init(allocator);

    // Test data
    const original = "Deflate compression test data. " ** 20;

    // Compress
    const compressed = try comp.compress(original, .deflate);
    defer allocator.free(compressed);

    // Compressed should be smaller
    try testing.expect(compressed.len < original.len);

    // Decompress
    const decompressed = try comp.decompress(compressed, .deflate);
    defer allocator.free(decompressed);

    // Should match original
    try testing.expectEqualStrings(original, decompressed);
}

test "compression - none algorithm" {
    const compression = @import("features/compression.zig");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var comp = compression.Compression.init(allocator);

    const original = "No compression test";

    // Compress with none
    const compressed = try comp.compress(original, .none);
    defer allocator.free(compressed);

    // Should be same length
    try testing.expectEqual(original.len, compressed.len);
    try testing.expectEqualStrings(original, compressed);

    // Decompress
    const decompressed = try comp.decompress(compressed, .none);
    defer allocator.free(decompressed);

    try testing.expectEqualStrings(original, decompressed);
}