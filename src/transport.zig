const std = @import("std");
const net = std.net;
const http2 = struct {
    pub const connection = @import("http2/connection.zig");
    pub const frame = @import("http2/frame.zig");
    pub const stream = @import("http2/stream.zig");
};

pub const TransportError = error{
    ConnectionClosed,
    InvalidHeader,
    PayloadTooLarge,
    CompressionNotSupported,
    Http2Error,
};

pub const Transport = struct {
    stream: net.Stream,
    read_buf: []u8,
    write_buf: []u8,
    allocator: std.mem.Allocator,
    http2_conn: ?http2.connection.Connection,

    pub fn init(allocator: std.mem.Allocator, stream: net.Stream) !Transport {
        var transport = Transport{
            .stream = stream,
            .read_buf = try allocator.alloc(u8, 1024 * 64),
            .write_buf = try allocator.alloc(u8, 1024 * 64),
            .allocator = allocator,
            .http2_conn = null,
        };

        // Initialize HTTP/2 connection
        transport.http2_conn = try http2.connection.Connection.init(allocator);
        try transport.setupHttp2();

        return transport;
    }

    pub fn deinit(self: *Transport) void {
        if (self.http2_conn) |*conn| {
            conn.deinit();
        }
        self.allocator.free(self.read_buf);
        self.allocator.free(self.write_buf);
        self.stream.close();
    }

    fn setupHttp2(self: *Transport) !void {
        // Send HTTP/2 connection preface
        _ = try self.stream.write(http2.connection.Connection.PREFACE);

        // Send initial SETTINGS frame
        var settings_frame = try http2.frame.Frame.init(self.allocator);
        defer settings_frame.deinit(self.allocator);

        settings_frame.type = .SETTINGS;
        settings_frame.flags = 0;
        settings_frame.stream_id = 0;
        // Add your settings here
        var buffer: [4096]u8 = undefined;
        var writer = self.stream.writer(&buffer);
        try settings_frame.encode(&writer.interface);
    }

    pub fn readMessage(self: *Transport) ![]const u8 {
        // Read frame header first (9 bytes)
        const header_size = 9;
        var header: [header_size]u8 = undefined;
        const bytes_read = try self.stream.read(&header);
        if (bytes_read < header_size) return TransportError.ConnectionClosed;

        // Parse header manually
        const length = (@as(u24, header[0]) << 16) | (@as(u24, header[1]) << 8) | @as(u24, header[2]);
        const frame_type = header[3];

        // Read payload
        const payload = try self.allocator.alloc(u8, length);
        errdefer self.allocator.free(payload);

        if (length > 0) {
            const payload_read = try self.stream.read(payload);
            if (payload_read < length) {
                self.allocator.free(payload);
                return TransportError.ConnectionClosed;
            }
        }

        // For DATA frames, return payload
        if (frame_type == 0x0) { // DATA frame
            return payload;
        }

        self.allocator.free(payload);
        return TransportError.Http2Error;
    }

    pub fn writeMessage(self: *Transport, message: []const u8) !void {
        var data_frame = try http2.frame.Frame.init(self.allocator);
        defer data_frame.deinit(self.allocator);

        data_frame.type = .DATA;
        data_frame.flags = http2.frame.FrameFlags.END_STREAM;
        data_frame.stream_id = 1; // Use appropriate stream ID
        data_frame.payload = message;
        data_frame.length = @intCast(message.len);

        // Write frame header
        var header: [9]u8 = undefined;
        header[0] = @intCast((data_frame.length >> 16) & 0xFF);
        header[1] = @intCast((data_frame.length >> 8) & 0xFF);
        header[2] = @intCast(data_frame.length & 0xFF);
        header[3] = @intFromEnum(data_frame.type);
        header[4] = data_frame.flags;
        header[5] = @intCast((data_frame.stream_id >> 24) & 0xFF);
        header[6] = @intCast((data_frame.stream_id >> 16) & 0xFF);
        header[7] = @intCast((data_frame.stream_id >> 8) & 0xFF);
        header[8] = @intCast(data_frame.stream_id & 0xFF);

        _ = try self.stream.write(&header);
        if (message.len > 0) {
            _ = try self.stream.write(message);
        }
    }
};
