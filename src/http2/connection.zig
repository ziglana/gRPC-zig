const std = @import("std");
const frame = @import("frame.zig");
const stream = @import("stream.zig");
const hpack = @import("hpack.zig");

pub const ConnectionError = error{
    ProtocolError,
    StreamClosed,
    FlowControlError,
    SettingsTimeout,
    StreamError,
    CompressionError,
    ConnectionError,
};

pub const Connection = struct {
    streams: std.AutoHashMap(u31, stream.Stream),
    next_stream_id: u31,
    allocator: std.mem.Allocator,
    encoder: hpack.Encoder,
    decoder: hpack.Decoder,

    pub const PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";

    pub fn init(allocator: std.mem.Allocator) !Connection {
        return Connection{
            .streams = std.AutoHashMap(u31, stream.Stream).init(allocator),
            .next_stream_id = 1,
            .allocator = allocator,
            .encoder = try hpack.Encoder.init(allocator),
            .decoder = try hpack.Decoder.init(allocator),
        };
    }

    pub fn deinit(self: *Connection) void {
        var stream_it = self.streams.iterator();
        while (stream_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.streams.deinit();
        self.encoder.deinit();
        self.decoder.deinit();
    }

    pub fn createStream(self: *Connection) !*stream.Stream {
        const id = self.next_stream_id;
        self.next_stream_id += 2;

        const new_stream = try stream.Stream.init(id, self.allocator);
        try self.streams.put(id, new_stream);
        return self.streams.getPtr(id).?;
    }

    pub fn sendHeaders(self: *Connection, stream_id: u31, headers: std.StringHashMap([]const u8)) !void {
        // Encode headers using HPACK
        const encoded = try self.encoder.encode(headers);
        defer self.allocator.free(encoded);

        // Create HEADERS frame
        var headers_frame = try frame.Frame.init(self.allocator);
        defer headers_frame.deinit(self.allocator);

        headers_frame.type = .HEADERS;
        headers_frame.flags = frame.FrameFlags.END_HEADERS;
        headers_frame.stream_id = stream_id;
        headers_frame.payload = encoded;
        headers_frame.length = @intCast(encoded.len);

        // Send frame (implementation depends on transport layer)
        try self.sendFrame(headers_frame);
    }

    fn sendFrame(self: *Connection, f: frame.Frame) !void {
        // Implementation depends on transport layer
        _ = self;
        _ = f;
    }
};
