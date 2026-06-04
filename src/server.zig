const std = @import("std");
const spice = @import("spice");
const proto = @import("proto/service.zig");
const transport = @import("transport.zig");
const compression = @import("features/compression.zig");
const auth = @import("features/auth.zig");
const streaming = @import("features/streaming.zig");
const health = @import("features/health.zig");

pub const Handler = struct {
    name: []const u8,
    handler_fn: *const fn ([]const u8, std.mem.Allocator, std.Io) anyerror![]u8,
};

pub const GrpcServer = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    address: std.Io.net.IpAddress,
    server: std.Io.net.Server,
    handlers: std.ArrayList(Handler),
    compression: compression.Compression,
    auth: auth.Auth,
    health_check: health.HealthCheck,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, port: u16, secret_key: []const u8) !GrpcServer {
        const address = try std.Io.net.IpAddress.parse("127.0.0.1", port);
        const server = try address.listen(io, .{ .reuse_address = false });
        return GrpcServer{
            .allocator = allocator,
            .io = io,
            .address = address,
            .server = server,
            .handlers = try std.ArrayList(Handler).initCapacity(allocator, 1),
            .compression = compression.Compression.init(allocator),
            .auth = auth.Auth.init(allocator, io, secret_key),
            .health_check = health.HealthCheck.init(allocator),
        };
    }

    pub fn deinit(self: *GrpcServer) void {
        self.handlers.deinit(self.allocator);
        self.server.deinit(self.io);
        self.health_check.deinit();
    }

    pub fn start(self: *GrpcServer) !void {
        try self.health_check.setStatus("grpc.health.v1.Health", .SERVING);

        while (true) {
            const stream = try self.server.accept(self.io);
            // Handle connection errors gracefully - don't crash the server
            self.handleConnection(stream) catch |err| {
                std.log.err("Connection handling failed: {}", .{err});
                continue;
            };
        }
    }

    fn handleConnection(self: *GrpcServer, stream: std.Io.net.Stream) !void {
        var trans = try transport.Transport.initServer(self.allocator, self.io, stream);
        defer trans.deinit();

        // Setup streaming
        var message_stream = streaming.MessageStream.init(self.allocator, 1024);
        defer message_stream.deinit();

        while (true) {
            const message = trans.readMessage() catch |err| switch (err) {
                error.ConnectionClosed => break,
                else => return err,
            };
            defer self.allocator.free(message);

            // TODO: Extract headers from HTTP/2 frames for auth verification
            // For now, skip auth verification
            // try self.auth.verifyToken("");

            // TODO: Extract compression algorithm from HTTP/2 headers
            // For now, assume no compression on incoming messages
            const compression_alg = compression.Compression.Algorithm.none;
            const decompressed = try self.compression.decompress(message, compression_alg);
            defer self.allocator.free(decompressed);

            // Process message - only call the first handler
            // TODO: Implement proper method routing based on request headers
            if (self.handlers.items.len > 0) {
                const handler = self.handlers.items[0];
                const response = try handler.handler_fn(decompressed, self.allocator, self.io);
                defer self.allocator.free(response);

                // Use same compression as request
                const compressed = try self.compression.compress(response, compression_alg);
                defer self.allocator.free(compressed);

                try trans.writeMessage(compressed);
            }
        }
    }
};
