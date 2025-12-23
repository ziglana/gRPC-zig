const std = @import("std");

pub const EchoRequest = struct {
    message: []const u8,
    timestamp: i32,

    pub fn encode(self: EchoRequest, writer: anytype) !void {
        try writer.writeString(1, self.message);
        try writer.writeInt32(2, self.timestamp);
    }

    pub fn decode(reader: anytype) !EchoRequest {
        var message: ?[]const u8 = null;
        var timestamp: i32 = 0;
        while (try reader.next()) |field| {
            switch (field.number) {
                1 => message = try field.string(),
                2 => timestamp = try field.int32(),
                else => try field.skip(),
            }
        }
        return EchoRequest{
            .message = message orelse "",
            .timestamp = timestamp,
        };
    }
};

pub const EchoResponse = struct {
    message: []const u8,
    timestamp: i32,
    server_info: []const u8,

    pub fn encode(self: EchoResponse, writer: anytype) !void {
        try writer.writeString(1, self.message);
        try writer.writeInt32(2, self.timestamp);
        try writer.writeString(3, self.server_info);
    }

    pub fn decode(reader: anytype) !EchoResponse {
        var message: ?[]const u8 = null;
        var timestamp: i32 = 0;
        var server_info: ?[]const u8 = null;
        while (try reader.next()) |field| {
            switch (field.number) {
                1 => message = try field.string(),
                2 => timestamp = try field.int32(),
                3 => server_info = try field.string(),
                else => try field.skip(),
            }
        }
        return EchoResponse{
            .message = message orelse "",
            .timestamp = timestamp,
            .server_info = server_info orelse "",
        };
    }
};

pub const HealthCheckRequest = struct {
    service: []const u8,

    pub fn encode(self: HealthCheckRequest, writer: anytype) !void {
        try writer.writeString(1, self.service);
    }

    pub fn decode(reader: anytype) !HealthCheckRequest {
        var service: ?[]const u8 = null;
        while (try reader.next()) |field| {
            switch (field.number) {
                1 => service = try field.string(),
                else => try field.skip(),
            }
        }
        return HealthCheckRequest{ .service = service orelse "" };
    }
};

pub const ServingStatus = enum(i32) {
    UNKNOWN = 0,
    SERVING = 1,
    NOT_SERVING = 2,
    SERVICE_UNKNOWN = 3,
};

pub const HealthCheckResponse = struct {
    status: ServingStatus,

    pub fn encode(self: HealthCheckResponse, writer: anytype) !void {
        try writer.writeEnum(1, self.status);
    }

    pub fn decode(reader: anytype) !HealthCheckResponse {
        var status: ServingStatus = .UNKNOWN;
        while (try reader.next()) |field| {
            switch (field.number) {
                1 => status = try field.enumValue(ServingStatus),
                else => try field.skip(),
            }
        }
        return HealthCheckResponse{ .status = status };
    }
};
