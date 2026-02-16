const std = @import("std");
const types = @import("types.zig");
const json = std.json;

pub const MethodHandler = fn (params: types.JSONValue, allocator: std.mem.Allocator) anyerror!types.JSONValue;

pub const MCPServer = struct {
    allocator: std.mem.Allocator,
    capabilities: types.ServerCapabilities,
    serverInfo: types.ServerInfo,
    protocolVersion: []const u8,
    handlers: std.StringHashMap(MethodHandler),
    tools: std.ArrayList(types.Tool),
    resources: std.ArrayList(types.Resource_),
    resourceTemplates: std.ArrayList(types.ResourceTemplate),
    prompts: std.ArrayList(types.Prompt),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, version: []const u8) MCPServer {
        return MCPServer{
            .allocator = allocator,
            .capabilities = .{
                .tools = .{ .listChanged = false },
                .resources = .{ .subscribe = false, .listChanged = false },
                .prompts = .{ .listChanged = false },
                .sampling = .{},
            },
            .serverInfo = .{ .name = name, .version = version },
            .protocolVersion = "2025-11-25",
            .handlers = std.StringHashMap(MethodHandler).init(allocator),
            .tools = std.ArrayList(types.Tool).init(allocator),
            .resources = std.ArrayList(types.Resource_).init(allocator),
            .resourceTemplates = std.ArrayList(types.ResourceTemplate).init(allocator),
            .prompts = std.ArrayList(types.Prompt).init(allocator),
        };
    }

    pub fn deinit(self: *MCPServer) void {
        self.handlers.deinit();
        self.tools.deinit();
        self.resources.deinit();
        self.resourceTemplates.deinit();
        self.prompts.deinit();
    }

    pub fn registerTool(self: *MCPServer, name: []const u8, description: []const u8, handler: MethodHandler) !void {
        const tool = types.Tool{
            .name = name,
            .description = description,
            .inputSchema = std.json.ObjectMap.init(self.allocator),
        };
        try self.tools.append(tool);
        try self.handlers.put(try self.allocator.dupe(u8, name), handler);
    }

    pub fn registerResource(self: *MCPServer, uri: []const u8, name: []const u8, description: []const u8, mimeType: []const u8) !void {
        const resource = types.Resource_{
            .uri = uri,
            .name = name,
            .description = description,
            .mimeType = mimeType,
        };
        try self.resources.append(resource);
    }

    pub fn registerPrompt(self: *MCPServer, name: []const u8, description: []const u8) !void {
        const prompt = types.Prompt{
            .name = name,
            .description = description,
            .arguments = null,
        };
        try self.prompts.append(prompt);
    }

    pub fn handleMessage(self: *MCPServer, data: []const u8) ![]u8 {
        const msg = try types.parseMessage(self.allocator, data);
        defer {
            // Clean up parsed message if needed
        }

        switch (msg) {
            .request => |req| {
                const result = try self.handleRequest(req);
                const response = types.JSONRPCMessage{
                    .response = .{
                        .jsonrpc = types.JSONRPCVersion,
                        .id = req.id,
                        .result = result,
                    },
                };
                return try types.serializeMessage(self.allocator, response);
            },
            .notification => |notif| {
                try self.handleNotification(notif);
                return &[_]u8{};
            },
            .error => |err| {
                const response = types.JSONRPCMessage{
                    .error = .{
                        .jsonrpc = types.JSONRPCVersion,
                        .id = err.id,
                        .error = .{
                            .code = .InvalidRequest,
                            .message = "Received error message",
                        },
                    },
                };
                return try types.serializeMessage(self.allocator, response);
            },
            .response => |_| {
                // Ignore unexpected responses
                return &[_]u8{};
            },
        }
    }

    fn handleRequest(self: *MCPServer, req: types.JSONRPCRequest) !types.JSONValue {
        if (std.mem.eql(u8, req.method, "initialize")) {
            return try self.handleInitialize(req.params);
        } else if (std.mem.eql(u8, req.method, "ping")) {
            return try self.handlePing(req.params);
        } else if (std.mem.eql(u8, req.method, "tools/list")) {
            return try self.handleToolsList(req.params);
        } else if (std.mem.eql(u8, req.method, "tools/call")) {
            return try self.handleToolsCall(req.params);
        } else if (std.mem.eql(u8, req.method, "resources/list")) {
            return try self.handleResourcesList(req.params);
        } else if (std.mem.eql(u8, req.method, "resources/read")) {
            return try self.handleResourcesRead(req.params);
        } else if (std.mem.eql(u8, req.method, "resources/templates/list")) {
            return try self.handleResourceTemplatesList(req.params);
        } else if (std.mem.eql(u8, req.method, "prompts/list")) {
            return try self.handlePromptsList(req.params);
        } else if (std.mem.eql(u8, req.method, "prompts/get")) {
            return try self.handlePromptsGet(req.params);
        } else if (std.mem.eql(u8, req.method, "sampling/createMessage")) {
            return try self.handleSampling(req.params);
        } else {
            return types.JSONValue{ .null = {} };
        }
    }

    fn handleNotification(self: *MCPServer, notif: types.JSONRPCNotification) !void {
        if (std.mem.eql(u8, notif.method, "notifications/initialized")) {
            // Client has finished initialization
            std.log.info("MCP client initialized", .{});
        }
    }

    fn handleInitialize(self: *MCPServer, params: ?types.JSONValue) !types.JSONValue {
        if (params) |p| {
            if (p == .object) {
                if (p.object.get("protocolVersion")) |pv| {
                    self.protocolVersion = try self.allocator.dupe(u8, pv.string);
                }
            }
        }

        const result = types.InitializeResult{
            .protocolVersion = self.protocolVersion,
            .capabilities = self.capabilities,
            .serverInfo = self.serverInfo,
        };

        var obj = std.json.ObjectMap.init(self.allocator);
        try obj.put("protocolVersion", .{ .string = result.protocolVersion });
        try obj.put("capabilities", try jsonValueFromCapabilities(self.allocator, result.capabilities));
        try obj.put("serverInfo", try jsonValueFromServerInfo(self.allocator, result.serverInfo));

        return .{ .object = obj };
    }

    fn handlePing(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        return .{ .object = std.json.ObjectMap.init(self.allocator) };
    }

    fn handleToolsList(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        var tools_array = std.json.Array.init(self.allocator);
        for (self.tools.items) |tool| {
            var tool_obj = std.json.ObjectMap.init(self.allocator);
            try tool_obj.put("name", .{ .string = tool.name });
            try tool_obj.put("description", .{ .string = tool.description });
            try tools_array.append(.{ .object = tool_obj });
        }

        var result = std.json.ObjectMap.init(self.allocator);
        try result.put("tools", .{ .array = tools_array });

        return .{ .object = result };
    }

    fn handleToolsCall(self: *MCPServer, params: ?types.JSONValue) !types.JSONValue {
        if (params == null or params.? != .object) {
            return types.JSONValue{ .null = {} };
        }

        const params_obj = params.?.object;
        const name = params_obj.get("name").?.string;

        if (self.handlers.get(name)) |handler| {
            const arguments = params_obj.get("arguments");
            const result = try handler(arguments orelse .{ .object = std.json.ObjectMap.init(self.allocator) }, self.allocator);
            return result;
        }

        // Return error
        var error_obj = std.json.ObjectMap.init(self.allocator);
        try error_obj.put("content", .{ .array = std.json.Array.init(self.allocator) });
        try error_obj.put("isError", .{ .bool = true });

        return .{ .object = error_obj };
    }

    fn handleResourcesList(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        var resources_array = std.json.Array.init(self.allocator);
        for (self.resources.items) |resource| {
            var res_obj = std.json.ObjectMap.init(self.allocator);
            try res_obj.put("uri", .{ .string = resource.uri });
            try res_obj.put("name", .{ .string = resource.name });
            try res_obj.put("description", .{ .string = resource.description });
            try res_obj.put("mimeType", .{ .string = resource.mimeType });
            try resources_array.append(.{ .object = res_obj });
        }

        var result = std.json.ObjectMap.init(self.allocator);
        try result.put("resources", .{ .array = resources_array });

        return .{ .object = result };
    }

    fn handleResourcesRead(self: *MCPServer, params: ?types.JSONValue) !types.JSONValue {
        if (params == null or params.? != .object) {
            return types.JSONValue{ .null = {} };
        }

        const params_obj = params.?.object;
        const uri = params_obj.get("uri").?.string;

        // Return empty content for now - implement actual resource reading
        var contents_array = std.json.Array.init(self.allocator);
        var result = std.json.ObjectMap.init(self.allocator);
        try result.put("contents", .{ .array = contents_array });

        return .{ .object = result };
    }

    fn handleResourceTemplatesList(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        var templates_array = std.json.Array.init(self.allocator);

        var result = std.json.ObjectMap.init(self.allocator);
        try result.put("resourceTemplates", .{ .array = templates_array });

        return .{ .object = result };
    }

    fn handlePromptsList(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        var prompts_array = std.json.Array.init(self.allocator);
        for (self.prompts.items) |prompt| {
            var prompt_obj = std.json.ObjectMap.init(self.allocator);
            try prompt_obj.put("name", .{ .string = prompt.name });
            try prompt_obj.put("description", .{ .string = prompt.description });
            try prompts_array.append(.{ .object = prompt_obj });
        }

        var result = std.json.ObjectMap.init(self.allocator);
        try result.put("prompts", .{ .array = prompts_array });

        return .{ .object = result };
    }

    fn handlePromptsGet(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        return types.JSONValue{ .null = {} };
    }

    fn handleSampling(self: *MCPServer, _: ?types.JSONValue) !types.JSONValue {
        return types.JSONValue{ .null = {} };
    }
};

fn jsonValueFromCapabilities(allocator: std.mem.Allocator, caps: types.ServerCapabilities) !types.JSONValue {
    var obj = std.json.ObjectMap.init(allocator);

    if (caps.tools) |_| {
        var tools_obj = std.json.ObjectMap.init(allocator);
        try tools_obj.put("listChanged", .{ .bool = false });
        try obj.put("tools", .{ .object = tools_obj });
    }

    if (caps.resources) |_| {
        var res_obj = std.json.ObjectMap.init(allocator);
        try res_obj.put("subscribe", .{ .bool = false });
        try res_obj.put("listChanged", .{ .bool = false });
        try obj.put("resources", .{ .object = res_obj });
    }

    if (caps.prompts) |_| {
        var prompts_obj = std.json.ObjectMap.init(allocator);
        try prompts_obj.put("listChanged", .{ .bool = false });
        try obj.put("prompts", .{ .object = prompts_obj });
    }

    if (caps.sampling) |_| {
        try obj.put("sampling", .{ .object = std.json.ObjectMap.init(allocator) });
    }

    return .{ .object = obj };
}

fn jsonValueFromServerInfo(allocator: std.mem.Allocator, info: types.ServerInfo) !types.JSONValue {
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("name", .{ .string = info.name });
    try obj.put("version", .{ .string = info.version });
    return .{ .object = obj };
}
