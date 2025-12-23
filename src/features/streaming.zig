const std = @import("std");

pub const StreamError = error{
    Closed,
    BufferFull,
};

pub const StreamingMessage = struct {
    data: []const u8,
    is_end: bool,
};

pub const MessageStream = struct {
    buffer: std.ArrayList(StreamingMessage),
    allocator: std.mem.Allocator,
    max_buffer_size: usize,

    pub fn init(allocator: std.mem.Allocator, max_buffer_size: usize) MessageStream {
        return .{
            .buffer = std.ArrayList(StreamingMessage){},
            .allocator = allocator,
            .max_buffer_size = max_buffer_size,
        };
    }

    pub fn deinit(self: *MessageStream) void {
        for (self.buffer.items) |msg| {
            self.allocator.free(msg.data);
        }
        self.buffer.deinit(self.allocator);
    }

    pub fn push(self: *MessageStream, data: []const u8, is_end: bool) !void {
        if (self.buffer.items.len >= self.max_buffer_size) {
            return StreamError.BufferFull;
        }

        const msg = StreamingMessage{
            .data = try self.allocator.dupe(u8, data),
            .is_end = is_end,
        };
        try self.buffer.append(self.allocator, msg);
    }

    pub fn pop(self: *MessageStream) ?StreamingMessage {
        if (self.buffer.items.len == 0) return null;
        return self.buffer.orderedRemove(0);
    }
};