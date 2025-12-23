const std = @import("std");
const spice = @import("spice");
const proto = @import("proto/service.zig");
const transport = @import("transport.zig");
const compression = @import("features/compression.zig");
const auth = @import("features/auth.zig");
const streaming = @import("features/streaming.zig");
const health = @import("features/health.zig");

pub const GrpcClient = struct {
    allocator: std.mem.Allocator,
    transport: transport.Transport,
    compression: compression.Compression,
    auth: ?auth.Auth,

    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) !GrpcClient {
        const connection = try std.net.tcpConnectToHost(allocator, host, port);

        return GrpcClient{
            .allocator = allocator,
            .transport = try transport.Transport.initClient(allocator, connection),
            .compression = compression.Compression.init(allocator),
            .auth = null,
        };
    }

    pub fn deinit(self: *GrpcClient) void {
        self.transport.deinit();
    }

    pub fn setAuth(self: *GrpcClient, secret_key: []const u8) !void {
        self.auth = auth.Auth.init(self.allocator, secret_key);
    }

    pub fn checkHealth(self: *GrpcClient, service: []const u8) !health.HealthStatus {
        const request = try std.json.stringify(.{
            .service = service,
        }, .{}, self.allocator);
        defer self.allocator.free(request);

        const response = try self.call("Check", request, .none);
        defer self.allocator.free(response);

        const parsed = try std.json.parse(struct {
            status: health.HealthStatus,
        }, .{ .allocator = self.allocator }, response);
        defer std.json.parseFree(parsed, .{ .allocator = self.allocator });

        return parsed.status;
    }

    pub fn call(self: *GrpcClient, _: []const u8, request: []const u8, compression_alg: compression.Compression.Algorithm) ![]u8 {
        // Add auth token if available
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        defer headers.deinit();

        if (self.auth) |*auth_client| {
            const token = try auth_client.generateToken("client", 3600);
            defer self.allocator.free(token);
            try headers.put("authorization", token);
        }

        // Compress request
        const compressed = try self.compression.compress(request, compression_alg);
        defer self.allocator.free(compressed);

        try self.transport.writeMessage(compressed);
        const response_bytes = try self.transport.readMessage();
        defer self.allocator.free(response_bytes);

        // Decompress response
        return self.compression.decompress(response_bytes, compression_alg);
    }
};
