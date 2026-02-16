const std = @import("std");
const types = @import("types.zig");

pub const Transport = union(enum) {
    stdio: StdioTransport,
    http: HttpTransport,
};

pub const StdioTransport = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StdioTransport {
        return StdioTransport{
            .allocator = allocator,
        };
    }

    pub fn readMessage(self: StdioTransport) ![]u8 {
        // Read length as 4-byte big-endian integer
        var len_buf: [4]u8 = undefined;
        const bytes_read = try std.os.read(std.os.STDIN_FILENO, &len_buf);
        if (bytes_read == 0) {
            return error.ConnectionClosed;
        }
        if (bytes_read < 4) {
            return error.InvalidMessage;
        }

        const len = std.mem.readBig(u32, &len_buf);
        if (len > 10 * 1024 * 1024) {
            return error.MessageTooLarge;
        }

        const message = try self.allocator.alloc(u8, len);
        errdefer self.allocator.free(message);

        var remaining = len;
        var offset: usize = 0;
        while (remaining > 0) {
            const read = try std.os.read(std.os.STDIN_FILENO, message[offset..]);
            if (read == 0) {
                return error.ConnectionClosed;
            }
            offset += read;
            remaining -= read;
        }

        return message;
    }

    pub fn writeMessage(self: StdioTransport, data: []const u8) !void {
        // Write length as 4-byte big-endian integer followed by data
        var len_buf: [4]u8 = undefined;
        std.mem.writeBig(u32, &len_buf, @intCast(data.len));

        var total_written: usize = 0;
        while (total_written < 4) {
            const written = try std.os.write(std.os.STDOUT_FILENO, len_buf[total_written..]);
            if (written == 0) {
                return error.ConnectionClosed;
            }
            total_written += written;
        }

        total_written = 0;
        while (total_written < data.len) {
            const written = try std.os.write(std.os.STDOUT_FILENO, data[total_written..]);
            if (written == 0) {
                return error.ConnectionClosed;
            }
            total_written += written;
        }
    }
};

pub const HttpTransport = struct {
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) HttpTransport {
        return HttpTransport{
            .allocator = allocator,
            .stream = stream,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *HttpTransport) void {
        self.buffer.deinit();
    }

    pub fn readMessage(self: *HttpTransport) ![]u8 {
        // Read HTTP headers
        var header_buf = [4096]u8{};
        var header_end: usize = 0;
        
        while (true) {
            const bytes_read = try self.stream.read(header_buf[header_end..header_end + 1]);
            if (bytes_read == 0) {
                return error.ConnectionClosed;
            }

            if (header_end >= 3 and 
                header_buf[header_end - 3] == '\r' and 
                header_buf[header_end - 2] == '\n' and 
                header_buf[header_end - 1] == '\r' and
                header_end >= 1 and header_buf[header_end] == '\n') {
                break;
            }
            header_end += bytes_read;
        }

        // Parse Content-Length header
        const headers = header_buf[0..header_end];
        var content_length: usize = 0;
        var lines = std.mem.split(u8, headers, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
                const value = std.mem.trim(u8, line[15..], " ");
                content_length = try std.fmt.parseInt(usize, value, 10);
            }
        }

        if (content_length == 0) {
            return error.InvalidMessage;
        }

        // Read body
        const body = try self.allocator.alloc(u8, content_length);
        errdefer self.allocator.free(body);

        var remaining = content_length;
        var offset: usize = 0;
        while (remaining > 0) {
            const read = try self.stream.read(body[offset..]);
            if (read == 0) {
                return error.ConnectionClosed;
            }
            offset += read;
            remaining -= read;
        }

        return body;
    }

    pub fn writeMessage(self: *HttpTransport, data: []const u8) !void {
        // Write HTTP response with SSE
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.writer().print(
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/event-stream\r\n" ++
            "Cache-Control: no-cache\r\n" ++
            "Connection: keep-alive\r\n" ++
            "Transfer-Encoding: chunked\r\n" ++
            "\r\n",
            .{}
        );

        // Write chunked body
        try buf.writer().print("{x}\r\n", .{data.len});
        try buf.appendSlice(data);
        try buf.appendSlice("\r\n");
        try buf.appendSlice("0\r\n\r\n");

        try self.stream.writeAll(buf.items);
    }
};

pub fn runStdioServer(allocator: std.mem.Allocator, server: anytype) !void {
    var transport = StdioTransport.init(allocator);

    while (true) {
        const message = transport.readMessage() catch |err| {
            if (err == error.ConnectionClosed) {
                break;
            }
            std.log.err("Failed to read message: {}", .{err});
            continue;
        };

        const response = server.handleMessage(message) catch |err| {
            std.log.err("Failed to handle message: {}", .{err});
            allocator.free(message);
            continue;
        };
        allocator.free(message);

        if (response.len > 0) {
            transport.writeMessage(response) catch |err| {
                std.log.err("Failed to write response: {}", .{err});
                break;
            };
            allocator.free(response);
        }
    }
}
