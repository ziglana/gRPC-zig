const std = @import("std");
const c = @cImport({
    @cInclude("zlib.h");
});

pub const CompressionError = error{
    CompressionFailed,
    DecompressionFailed,
    OutOfMemory,
};

pub const Compression = struct {
    pub const Algorithm = enum {
        none,
        gzip,
        deflate,
    };

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Compression {
        return .{ .allocator = allocator };
    }

    pub fn compress(self: *Compression, data: []const u8, algorithm: Algorithm) ![]u8 {
        switch (algorithm) {
            .none => return self.allocator.dupe(u8, data),
            .gzip, .deflate => {
                if (data.len == 0) return self.allocator.dupe(u8, data);

                // Allocate output buffer (worst case: input size + 0.1% + 12 bytes)
                const max_compressed_size = c.compressBound(@intCast(data.len));
                const compressed_buf = try self.allocator.alloc(u8, max_compressed_size);
                errdefer self.allocator.free(compressed_buf);

                var dest_len: c.uLongf = max_compressed_size;
                const result = if (algorithm == .gzip)
                    // For gzip, use compress2 with default compression level
                    c.compress2(
                        compressed_buf.ptr,
                        &dest_len,
                        data.ptr,
                        @intCast(data.len),
                        c.Z_DEFAULT_COMPRESSION,
                    )
                else
                    // For deflate, use compress
                    c.compress(
                        compressed_buf.ptr,
                        &dest_len,
                        data.ptr,
                        @intCast(data.len),
                    );

                if (result != c.Z_OK) {
                    self.allocator.free(compressed_buf);
                    return CompressionError.CompressionFailed;
                }

                // Resize to actual compressed size
                return self.allocator.realloc(compressed_buf, dest_len) catch compressed_buf[0..dest_len];
            },
        }
    }

    pub fn decompress(self: *Compression, data: []const u8, algorithm: Algorithm) ![]u8 {
        switch (algorithm) {
            .none => return self.allocator.dupe(u8, data),
            .gzip, .deflate => {
                if (data.len == 0) return self.allocator.dupe(u8, data);

                // Start with a buffer 4x the compressed size
                var decompressed_size: usize = data.len * 4;
                var decompressed_buf = try self.allocator.alloc(u8, decompressed_size);
                errdefer self.allocator.free(decompressed_buf);

                // Try decompressing, growing buffer if needed
                var attempts: u32 = 0;
                while (attempts < 5) : (attempts += 1) {
                    var dest_len: c.uLongf = @intCast(decompressed_size);
                    const result = c.uncompress(
                        decompressed_buf.ptr,
                        &dest_len,
                        data.ptr,
                        @intCast(data.len),
                    );

                    if (result == c.Z_OK) {
                        // Success! Resize to actual size
                        return self.allocator.realloc(decompressed_buf, dest_len) catch decompressed_buf[0..dest_len];
                    } else if (result == c.Z_BUF_ERROR) {
                        // Buffer too small, double the size and try again
                        self.allocator.free(decompressed_buf);
                        decompressed_size *= 2;
                        decompressed_buf = try self.allocator.alloc(u8, decompressed_size);
                    } else {
                        // Other error
                        self.allocator.free(decompressed_buf);
                        return CompressionError.DecompressionFailed;
                    }
                }

                self.allocator.free(decompressed_buf);
                return CompressionError.DecompressionFailed;
            },
        }
    }
};