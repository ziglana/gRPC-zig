const std = @import("std");
const mcp = @import("mcp");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create MCP server
    var server = mcp.server.MCPServer.init(allocator, "gRPC-zig MCP Server", "1.0.0");
    defer server.deinit();

    // Register a simple echo tool
    try server.registerTool("echo", "Echo back the input text", echoHandler);

    // Register a greeting tool
    try server.registerTool("greet", "Generate a greeting message", greetHandler);

    // Register a sample resource
    try server.registerResource("example://hello", "Hello Resource", "A simple hello world resource", "text/plain");

    // Register a sample prompt
    try server.registerTool("generate_prompt", "Generate a prompt for AI", promptHandler);

    std.debug.print("Starting MCP server on stdio...\n", .{});

    // Run the server
    try mcp.transport.runStdioServer(allocator, &server);
}

fn echoHandler(params: mcp.types.JSONValue, allocator: std.mem.Allocator) !mcp.types.JSONValue {
    var obj = std.json.ObjectMap.init(allocator);
    var content_array = std.json.Array.init(allocator);

    var content_obj = std.json.ObjectMap.init(allocator);
    try content_obj.put("type", .{ .string = "text" });

    var text = "echo";
    if (params == .object) {
        if (params.object.get("text")) |t| {
            text = t.string;
        }
    }
    try content_obj.put("text", .{ .string = text });

    try content_array.append(.{ .object = content_obj });
    try obj.put("content", .{ .array = content_array });
    try obj.put("isError", .{ .bool = false });

    return .{ .object = obj };
}

fn greetHandler(params: mcp.types.JSONValue, allocator: std.mem.Allocator) !mcp.types.JSONValue {
    var obj = std.json.ObjectMap.init(allocator);
    var content_array = std.json.Array.init(allocator);

    var content_obj = std.json.ObjectMap.init(allocator);
    try content_obj.put("type", .{ .string = "text" });

    var name = "World";
    if (params == .object) {
        if (params.object.get("name")) |n| {
            name = n.string;
        }
    }
    const greeting = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
    defer allocator.free(greeting);

    try content_obj.put("text", .{ .string = greeting });
    try content_array.append(.{ .object = content_obj });
    try obj.put("content", .{ .array = content_array });
    try obj.put("isError", .{ .bool = false });

    return .{ .object = obj };
}

fn promptHandler(params: mcp.types.JSONValue, allocator: std.mem.Allocator) !mcp.types.JSONValue {
    var obj = std.json.ObjectMap.init(allocator);
    var content_array = std.json.Array.init(allocator);

    var content_obj = std.json.ObjectMap.init(allocator);
    try content_obj.put("type", .{ .string = "text" });

    var task = "general";
    if (params == .object) {
        if (params.object.get("task")) |t| {
            task = t.string;
        }
    }

    const prompt_text = switch (task[0]) {
        's' => "Summarize the following: ",
        'e' => "Explain the following: ",
        else => "Analyze the following: ",
    };

    try content_obj.put("text", .{ .string = prompt_text });
    try content_array.append(.{ .object = content_obj });
    try obj.put("content", .{ .array = content_array });
    try obj.put("isError", .{ .bool = false });

    return .{ .object = obj };
}
