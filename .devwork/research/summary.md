# Research Summary

## Prompt
# PR #23: [WIP] Add support for MCP compatibility

## Description
Thanks for assigning this issue to me. I'm starting to work on it and will keep this PR's description up to date as I form a plan and make progress.

<!-- START COPILOT ORIGINAL PROMPT -->



<details>

<summary>Original prompt</summary>

> 
> ----
> 
> *This section details on the original issue you should resolve*
> 
> <issue_title>implement MCP</issue_title>
> <issue_description>add support of MCP, schema: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/2025-11-25/schema.ts
> 
> example of rust sdk: https://github.com/modelcontextprotocol/rust-sdk</issue_description>
> 
> <agent_instructions>mcp must be fully compatable with claude</agent_instructions>
> 
> ## Comments on the Issue (you are @copilot in this section)
> 
> <comments>
> </comments>
> 


</details>



<!-- START COPILOT CODING AGENT SUFFIX -->

- Fixes ziglana/gRPC-zig#22

<!-- START COPILOT CODING AGENT TIPS -->
---

💬 We'd love your input! Share your thoughts on Copilot coding agent in our [2 minute survey](https://gh.io/copilot-coding-agent-survey).


## Task
Thanks for assigning this issue to me. I'm starting to work on it and will keep this PR's description up to date as I form a plan and make progress.

<!-- START COPILOT ORIGINAL PROMPT -->



<details>

<summary>Original prompt</summary>

> 
> ----
> 
> *This section details on the original issue you should resolve*
> 
> <issue_title>implement MCP</issue_title>
> <issue_description>add support of MCP, schema: https://github.com/modelcontextprotocol/modelcontextprotocol/blob/main/schema/2025-11-25/schema.ts
> 
> example of rust sdk: https://github.com/modelcontextprotocol/rust-sdk</issue_description>
> 
> <agent_instructions>mcp must be fully compatable with claude</agent_instructions>
> 
> ## Comments on the Issue (you are @copilot in this section)
> 
> <comments>
> </comments>
> 


</details>



<!-- START COPILOT CODING AGENT SUFFIX -->

- Fixes ziglana/gRPC-zig#22

<!-- START COPILOT CODING AGENT TIPS -->
---

💬 We'd love your input! Share your thoughts on Copilot coding agent in our [2 minute survey](https://gh.io/copilot-coding-agent-survey).



## Findings
## Research Summary: Adding MCP Support to gRPC-zig

### Project Overview
- **Project**: gRPC-zig - A blazingly fast gRPC client & server implementation in Zig
- **Zig Version**: 0.15.2
- **Language**: Pure Zig (zero dependencies)
- **Location**: `/tmp/claudev-pr-95466`

### Project Structure
```
/tmp/claudev-pr-95466/
├── build.zig, build.zig.zon     # Zig build configuration
├── src/
│   ├── client.zig               # gRPC client implementation
│   ├── server.zig               # gRPC server implementation
│   ├── transport.zig            # Transport layer
│   ├── http2/                   # HTTP/2 protocol implementation
│   ├── proto/                   # Protocol buffer handling
│   ├── features/                # Features (auth, compression, streaming, health)
│   └── tests.zig, benchmark.zig
├── examples/                    # Example implementations
└── integration_test/
```

### MCP (Model Context Protocol) Overview

**MCP is a JSON-RPC 2.0 based protocol** for AI assistants to interact with tools and resources. Key points:

1. **Protocol Version**: 2025-11-25 (latest) or 2025-06-18
2. **Transport**: stdio or HTTP with SSE (Server-Sent Events)
3. **Message Types**:
   - `JSONRPCRequest` - expects response (has `id`)
   - `JSONRPCNotification` - no response expected (no `id`)
   - `JSONRPCResponse` - successful response
   - `JSONRPCErrorResponse` - error response

4. **Core Methods**:
   - `initialize` - Client/server handshake with capabilities
   - `notifications/initialized` - Client confirmation
   - `ping` - Keepalive/liveness check
   - `tools/list`, `tools/call` - Tool operations
   - `resources/list`, `resources/read`, `resources/subscribe` - Resource operations
   - `prompts/list`, `prompts/get` - Prompt templates
   - `sampling/createMessage` - LLM sampling

5. **Standard Error Codes**:
   - `-32700` - Parse error
   - `-32600` - Invalid request
   - `-32601` - Method not found
   - `-32602` - Invalid params
   - `-32603` - Internal error

### Implementation Requirements

To make MCP compatible with Claude:

1. **JSON-RPC 2.0 Compliance**: Must properly handle both requests and notifications
2. **Initialization Handshake**: 
   - Server responds to `initialize` with `ServerCapabilities`
   - Client sends `notifications/initialized` after receiving capabilities
3. **Capability Negotiation**: Both client and server declare their capabilities
4. **Transport Options**: 
   - stdio (common for local tools)
   - HTTP with SSE (for web-based servers)

### Key Gotchas

1. **Notification vs Request**: Notifications have no `id` field, requests have an `id`
2. **Progress Tokens**: Can be used for long-running operations with `notifications/progress`
3. **Content Types**: MCP uses its own content block types (TextContent, ImageContent, BlobResourceContents, EmbeddedResource)
4. **Progress Token**: Either string or number type

### Recommended Implementation Approach

Since gRPC-zig already provides HTTP/2 infrastructure, you could:
1. Add an MCP layer on top that handles JSON-RPC messaging
2. Reuse HTTP/2 transport for the transport layer
3. Implement the core methods (initialize, ping, tools, resources, prompts)
4. Ensure proper capability negotiation

The MCP implementation would be a new module that wraps or integrates with the existing gRPC server/client infrastructure, translating between JSON-RPC messages and the internal gRPC-zig types.
