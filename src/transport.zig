const std = @import("std");
const net = std.Io.net;
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
    io: std.Io,
    read_buf: []u8,
    write_buf: []u8,
    allocator: std.mem.Allocator,
    http2_conn: ?http2.connection.Connection,

    pub fn initClient(allocator: std.mem.Allocator, io: std.Io, stream: net.Stream) !Transport {
        var transport = Transport{
            .stream = stream,
            .io = io,
            .read_buf = try allocator.alloc(u8, 1024 * 64),
            .write_buf = try allocator.alloc(u8, 1024 * 64),
            .allocator = allocator,
            .http2_conn = null,
        };

        // Initialize HTTP/2 connection
        transport.http2_conn = try http2.connection.Connection.init(allocator);
        try transport.setupHttp2Client();

        return transport;
    }

    pub fn initServer(allocator: std.mem.Allocator, io: std.Io, stream: net.Stream) !Transport {
        var transport = Transport{
            .stream = stream,
            .io = io,
            .read_buf = try allocator.alloc(u8, 1024 * 64),
            .write_buf = try allocator.alloc(u8, 1024 * 64),
            .allocator = allocator,
            .http2_conn = null,
        };
        errdefer transport.deinit();

        // Initialize HTTP/2 connection
        transport.http2_conn = try http2.connection.Connection.init(allocator);
        try transport.setupHttp2Server();

        return transport;
    }

    pub fn deinit(self: *Transport) void {
        if (self.http2_conn) |*conn| {
            conn.deinit();
        }
        self.allocator.free(self.read_buf);
        self.allocator.free(self.write_buf);
        self.stream.close(self.io);
    }

    fn setupHttp2Client(self: *Transport) !void {
        // Client sends HTTP/2 connection preface
        try self.writeAll(http2.connection.Connection.PREFACE);

        // Send initial SETTINGS frame
        const settings_header: [9]u8 = .{
            0,                                            0, 0, // length: 0 (no settings parameters)
            @intFromEnum(http2.frame.FrameType.SETTINGS),
            0, // flags: none
            0, 0, 0, 0, // stream_id: 0
        };
        try self.writeAll(&settings_header);
    }

    fn setupHttp2Server(self: *Transport) !void {
        // Server receives and validates HTTP/2 connection preface
        var preface_buf: [24]u8 = undefined;
        try self.readExact(&preface_buf);

        // Validate preface
        if (!std.mem.eql(u8, &preface_buf, http2.connection.Connection.PREFACE)) {
            return TransportError.Http2Error;
        }

        // Read client's SETTINGS frame
        var settings_header: [9]u8 = undefined;
        try self.readExact(&settings_header);

        // TODO: Parse and process SETTINGS frame properly
        // For now, just skip the payload if any
        const settings_length = (@as(u24, settings_header[0]) << 16) |
            (@as(u24, settings_header[1]) << 8) |
            @as(u24, settings_header[2]);
        if (settings_length > 0) {
            const settings_payload = try self.allocator.alloc(u8, settings_length);
            defer self.allocator.free(settings_payload);
            try self.readExact(settings_payload);
        }

        // Send server's SETTINGS frame
        const settings_response: [9]u8 = .{
            0,                                            0, 0, // length: 0
            @intFromEnum(http2.frame.FrameType.SETTINGS),
            0, // flags: none
            0, 0, 0, 0, // stream_id: 0
        };
        try self.writeAll(&settings_response);

        // Send SETTINGS ACK for client's settings
        const settings_ack: [9]u8 = .{
            0,                                            0, 0, // length: 0
            @intFromEnum(http2.frame.FrameType.SETTINGS),
            0x1, // flags: ACK
            0, 0, 0, 0, // stream_id: 0
        };
        try self.writeAll(&settings_ack);
    }

    pub fn readMessage(self: *Transport) ![]const u8 {
        // Read frame header first (9 bytes)
        const header_size = 9;
        var header: [header_size]u8 = undefined;
        try self.readExact(&header);

        // Parse header manually
        const length = (@as(u24, header[0]) << 16) | (@as(u24, header[1]) << 8) | @as(u24, header[2]);
        const frame_type = header[3];

        // Read payload
        const payload = try self.allocator.alloc(u8, length);
        errdefer self.allocator.free(payload);

        if (length > 0) {
            try self.readExact(payload);
        }

        // For DATA frames, return payload
        if (frame_type == @intFromEnum(http2.frame.FrameType.DATA)) {
            return payload;
        }

        return TransportError.Http2Error;
    }

    pub fn writeMessage(self: *Transport, message: []const u8) !void {
        const frame_type = http2.frame.FrameType.DATA;
        const frame_flags = http2.frame.FrameFlags.END_STREAM;
        const stream_id: u31 = 1; // Use appropriate stream ID
        const length: u24 = @intCast(message.len);

        // Write frame header
        var header: [9]u8 = undefined;
        header[0] = @intCast((length >> 16) & 0xFF);
        header[1] = @intCast((length >> 8) & 0xFF);
        header[2] = @intCast(length & 0xFF);
        header[3] = @intFromEnum(frame_type);
        header[4] = frame_flags;
        header[5] = @intCast((stream_id >> 24) & 0xFF);
        header[6] = @intCast((stream_id >> 16) & 0xFF);
        header[7] = @intCast((stream_id >> 8) & 0xFF);
        header[8] = @intCast(stream_id & 0xFF);

        try self.writeAll(&header);
        if (message.len > 0) {
            try self.writeAll(message);
        }
    }

    fn readOnce(self: *Transport, buffer: []u8) !usize {
        var data: [1][]u8 = .{buffer};
        return self.stream.read(self.io, &data) catch |err| switch (err) {
            error.SocketUnconnected, error.ConnectionResetByPeer => 0,
            else => return err,
        };
    }

    fn readExact(self: *Transport, buffer: []u8) !void {
        var offset: usize = 0;
        while (offset < buffer.len) {
            const bytes_read = try self.readOnce(buffer[offset..]);
            if (bytes_read == 0) return TransportError.ConnectionClosed;
            offset += bytes_read;
        }
    }

    fn writeAll(self: *Transport, bytes: []const u8) !void {
        var remaining = bytes;
        while (remaining.len > 0) {
            const written = self.io.vtable.netWrite(
                self.io.userdata,
                self.stream.socket.handle,
                "",
                &.{remaining},
                1,
            ) catch |err| switch (err) {
                error.SocketUnconnected, error.ConnectionResetByPeer => return,
                else => return err,
            };
            if (written == 0) return;
            remaining = remaining[written..];
        }
    }
};
