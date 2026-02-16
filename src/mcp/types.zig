const std = @import("std");

pub const JSONRPCVersion = "2.0";

pub const ErrorCode = enum(i32) {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
};

pub const JSONRPCError = struct {
    code: ErrorCode,
    message: []const u8,
    data: ?[]const u8 = null,
};

pub const ProgressToken = union(enum) {
    string: []const u8,
    number: i64,
};

pub const JSONValue = union(enum) {
    null,
    bool: bool,
    number: f64,
    string: []const u8,
    array: []JSONValue,
    object: std.json.ObjectMap,
};

pub const TextContent = struct {
    type: []const u8 = "text",
    text: []const u8,
};

pub const ImageContent = struct {
    type: []const u8 = "image",
    data: []const u8,
    mimeType: []const u8,
};

pub const BlobResourceContents = struct {
    type: []const u8 = "blob",
    blob: []const u8,
    mimeType: []const u8,
};

pub const EmbeddedResource = struct {
    type: []const u8 = "resource",
    resource: Resource,
};

pub const Content = union(enum) {
    text: TextContent,
    image: ImageContent,
    blob: BlobResourceContents,
    embedded: EmbeddedResource,
};

pub const Resource = struct {
    uri: []const u8,
    mimeType: []const u8,
    text: ?[]const u8 = null,
    blob: ?[]const u8 = null,
};

pub const TextResourceContents = struct {
    uri: []const u8,
    mimeType: []const u8,
    text: []const u8,
};

pub const CallToolResult = struct {
    content: []Content,
    isError: bool = false,
};

pub const Tool = struct {
    name: []const u8,
    description: []const u8,
    inputSchema: std.json.ObjectMap,
};

pub const ResourceTemplate = struct {
    uriTemplate: []const u8,
    name: []const u8,
    description: []const u8,
    mimeType: []const u8,
};

pub const Resource_ = struct {
    uri: []const u8,
    name: []const u8,
    description: []const u8,
    mimeType: []const u8,
};

pub const Prompt = struct {
    name: []const u8,
    description: []const u8,
    arguments: ?[]struct {
        name: []const u8,
        description: []const u8,
        required: bool,
    } = null,
};

pub const PromptMessage = struct {
    role: []const u8,
    content: Content,
};

pub const PromptResult = struct {
    messages: []PromptMessage,
};

pub const SamplingMessage = struct {
    role: []const u8,
    content: Content,
};

pub const CreateMessageRequest = struct {
    messages: []SamplingMessage,
    systemPrompt: ?[]const u8 = null,
    includeContext: []const u8,
    temperature: ?f64 = null,
    maxTokens: ?u32 = null,
};

pub const CreateMessageResult = struct {
    role: []const u8,
    content: Content,
    model: []const u8,
    stopReason: []const u8,
};

pub const InitializeResult = struct {
    protocolVersion: []const u8,
    capabilities: ServerCapabilities,
    serverInfo: ServerInfo,
};

pub const ServerCapabilities = struct {
    tools: ?struct {
        listChanged: bool = false,
    } = null,
    resources: ?struct {
        subscribe: bool = false,
        listChanged: bool = false,
    } = null,
    prompts: ?struct {
        listChanged: bool = false,
    } = null,
    sampling: ?struct {},
};

pub const ServerInfo = struct {
    name: []const u8,
    version: []const u8,
};

pub const ClientCapabilities = struct {
    tools: ?struct {
        listChanged: bool = false,
    } = null,
    resources: ?struct {
        subscribe: bool = false,
        listChanged: bool = false,
    } = null,
    prompts: ?struct {
        listChanged: bool = false,
    } = null,
    sampling: ?struct {},
};

pub const InitializeParams = struct {
    protocolVersion: []const u8,
    capabilities: ClientCapabilities,
    clientInfo: ClientInfo,
};

pub const ClientInfo = struct {
    name: []const u8,
    version: []const u8,
};

pub const EmptyParams = struct {};

pub const ListToolsResult = struct {
    tools: []Tool,
};

pub const ListResourcesResult = struct {
    resources: []Resource_,
};

pub const ListResourceTemplatesResult = struct {
    resourceTemplates: []ResourceTemplate,
};

pub const ListPromptsResult = struct {
    prompts: []Prompt,
};

pub const ReadResourceResult = struct {
    contents: []const union(enum) {
        TextResourceContents,
        BlobResourceContents,
    },
};

pub const JSONRPCMessage = union(enum) {
    request: JSONRPCRequest,
    notification: JSONRPCNotification,
    response: JSONRPCResponse,
    error: JSONRPCErrorResponse,
};

pub const JSONRPCRequest = struct {
    jsonrpc: []const u8,
    id: union(enum) {
        string: []const u8,
        number: i64,
    },
    method: []const u8,
    params: ?JSONValue = null,
};

pub const JSONRPCNotification = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: ?JSONValue = null,
};

pub const JSONRPCResponse = struct {
    jsonrpc: []const u8,
    id: union(enum) {
        string: []const u8,
        number: i64,
    },
    result: JSONValue,
};

pub const JSONRPCErrorResponse = struct {
    jsonrpc: []const u8,
    id: ?union(enum) {
        string: []const u8,
        number: i64,
    } = null,
    error: JSONRPCError,
};

pub fn parseMessage(allocator: std.mem.Allocator, data: []const u8) !JSONRPCMessage {
    const parsed = try std.json.parseFromSlice(JSONValue, allocator, data, .{});
    defer parsed.deinit();

    const value = parsed.value;
    if (value != .object) {
        return error.InvalidJSON;
    }

    const obj = value.object;

    // Check if it's a request (has method and id)
    if (obj.get("method")) |method_val| {
        if (obj.get("id")) |id_val| {
            // Request
            const method = method_val.string;
            const id = if (id_val == .number) .{ number = @intCast(id_val.number) } else .{ string = id_val.string };
            const params = if (obj.get("params")) |p| p else null;

            return JSONRPCMessage{
                .request = .{
                    .jsonrpc = JSONRPCVersion,
                    .id = id,
                    .method = method,
                    .params = params,
                },
            };
        } else {
            // Notification
            const method = method_val.string;
            const params = if (obj.get("params")) |p| p else null;

            return JSONRPCMessage{
                .notification = .{
                    .jsonrpc = JSONRPCVersion,
                    .method = method,
                    .params = params,
                },
            };
        }
    }

    // Check if it's an error response
    if (obj.get("error")) |_| {
        const id = if (obj.get("id")) |id_val| if (id_val == .number) .{ number = @intCast(id_val.number) } else .{ string = id_val.string } else null;
        const err_obj = obj.get("error").?.object;
        const code = @enumFromInt(@intFromFloat(err_obj.get("code").?.number));
        const message = err_obj.get("message").?.string;
        const data_val = if (err_obj.get("data")) |d| d.string else null;

        return JSONRPCMessage{
            .error = .{
                .jsonrpc = JSONRPCVersion,
                .id = id,
                .error = .{ .code = code, .message = message, .data = data_val },
            },
        };
    }

    // Must be a response
    const id = if (obj.get("id").?) |id_val| if (id_val == .number) .{ number = @intCast(id_val.number) } else .{ string = id_val.string } else unreachable;
    const result = obj.get("result").?;

    return JSONRPCMessage{
        .response = .{
            .jsonrpc = JSONRPCVersion,
            .id = id,
            .result = result,
        },
    };
}

pub fn serializeMessage(allocator: std.mem.Allocator, msg: JSONRPCMessage) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    try serializeMessageWriter(msg, buf.writer());
    return buf.toOwnedSlice();
}

fn serializeMessageWriter(msg: JSONRPCMessage, writer: anytype) !void {
    switch (msg) {
        .request => |req| {
            try writer.writeByte('{');
            try writer.print("\"jsonrpc\":\"{s}\",\"id\":", .{req.jsonrpc});
            switch (req.id) {
                .string => |s| try writer.print("\"{s}\",", .{s}),
                .number => |n| try writer.print("{},", .{n}),
            }
            try writer.print("\"method\":\"{s}\"", .{req.method});
            if (req.params) |params| {
                try writer.writeByte(',');
                try writer.writeAll("\"params\":");
                try jsonValueWrite(params, writer);
            }
            try writer.writeByte('}');
        },
        .notification => |notif| {
            try writer.writeByte('{');
            try writer.print("\"jsonrpc\":\"{s}\",\"method\":\"{s}\"", .{notif.jsonrpc, notif.method});
            if (notif.params) |params| {
                try writer.writeByte(',');
                try writer.writeAll("\"params\":");
                try jsonValueWrite(params, writer);
            }
            try writer.writeByte('}');
        },
        .response => |resp| {
            try writer.writeByte('{');
            try writer.print("\"jsonrpc\":\"{s}\",\"id\":", .{resp.jsonrpc});
            switch (resp.id) {
                .string => |s| try writer.print("\"{s}\",", .{s}),
                .number => |n| try writer.print("{},", .{n}),
            }
            try writer.writeAll("\"result\":");
            try jsonValueWrite(resp.result, writer);
            try writer.writeByte('}');
        },
        .error => |err| {
            try writer.writeByte('{');
            try writer.print("\"jsonrpc\":\"{s}\",\"error\":{{"code":{},\"message\":\"{s}\"", .{err.jsonrpc, @intFromEnum(err.error.code), err.error.message});
            if (err.error.data) |data| {
                try writer.print(",\"data\":\"{s}\"", .{data});
            }
            try writer.writeByte('}');
            if (err.id) |id| {
                try writer.writeByte(',');
                try writer.writeAll("\"id\":");
                switch (id) {
                    .string => |s| try writer.print("\"{s}\"", .{s}),
                    .number => |n| try writer.writeAll("{}*{n}"),
                }
            }
            try writer.writeByte('}');
        },
    }
}

fn jsonValueWrite(val: JSONValue, writer: anytype) !void {
    switch (val) {
        .null => try writer.writeAll("null"),
        .bool => |b| try writer.writeAll(if (b) "true" else "false"),
        .number => |n| try writer.print("{}", .{n}),
        .string => |s| {
            try writer.writeByte('"');
            for (s) |c| {
                switch (c) {
                    '\\' => try writer.writeAll("\\\\"),
                    '"' => try writer.writeAll("\\\""),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeByte('"');
        },
        .array => |arr| {
            try writer.writeByte('[');
            for (arr, 0..) |item, i| {
                if (i > 0) try writer.writeByte(',');
                try jsonValueWrite(item, writer);
            }
            try writer.writeByte(']');
        },
        .object => |obj| {
            try writer.writeByte('{');
            var first = true;
            var it = obj.iterator();
            while (it.next()) |entry| {
                if (!first) try writer.writeByte(',');
                first = false;
                try writer.print("\"{s}\":", .{entry.key_ptr.*});
                try jsonValueWrite(entry.value_ptr.*, writer);
            }
            try writer.writeByte('}');
        },
    }
}
