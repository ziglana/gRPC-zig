const std = @import("std");

pub const FrameType = enum(u8) {
    DATA = 0x0,
    HEADERS = 0x1,
    PRIORITY = 0x2,
    RST_STREAM = 0x3,
    SETTINGS = 0x4,
    PUSH_PROMISE = 0x5,
    PING = 0x6,
    GOAWAY = 0x7,
    WINDOW_UPDATE = 0x8,
    CONTINUATION = 0x9,
};

pub const FrameFlags = struct {
    pub const END_STREAM = 0x1;
    pub const END_HEADERS = 0x4;
    pub const PADDED = 0x8;
    pub const PRIORITY = 0x20;
};

pub const Frame = struct {
    length: u24,
    type: FrameType,
    flags: u8,
    stream_id: u31,
    payload: []const u8,

    pub fn init(allocator: std.mem.Allocator) !Frame {
        return Frame{
            .length = 0,
            .type = .DATA,
            .flags = 0,
            .stream_id = 0,
            .payload = try allocator.alloc(u8, 0),
        };
    }

    pub fn deinit(self: *Frame, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
    }

    pub fn encode(self: Frame, writer: anytype) !void {
        try writer.writeInt(u24, self.length, .little);
        try writer.writeInt(u8, @intFromEnum(self.type), .little);
        try writer.writeInt(u8, self.flags, .little);
        try writer.writeInt(u32, self.stream_id, .little);
        try writer.writeAll(self.payload);
    }

    pub fn decode(reader: anytype, allocator: std.mem.Allocator) !Frame {
        var frame = try Frame.init(allocator);
        frame.length = try reader.readInt(u24, .big);
        frame.type = @enumFromInt(try reader.readInt(u8, .big));
        frame.flags = try reader.readInt(u8, .big);
        frame.stream_id = @intCast(try reader.readInt(u32, .big));

        frame.payload = try allocator.alloc(u8, frame.length);
        _ = try reader.readAll(frame.payload);

        return frame;
    }
};
