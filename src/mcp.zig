pub const mcp = struct {
    pub const types = @import("mcp/types.zig");
    pub const server = @import("mcp/server.zig");
    pub const transport = @import("mcp/transport.zig");
};
