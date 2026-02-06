# json-rpc-ld

Rails engine providing a unified JSON-RPC 2.0 API gateway with JSON-LD context support.

## Overview

This engine provides:
- **JSON-RPC 2.0** - Standard JSON-RPC endpoint for all Magentic services
- **MCP Protocol** - Model Context Protocol endpoint for AI tools
- **JSON-LD Context** - Linked Data vocabulary for semantic interoperability
- **Service Discovery** - Dynamic routing via mcp-skill-sot

## Dependencies

- `mcp-skill-sot` - For service/skill registry

## API Endpoints

Routes are namespaced under the engine mount point:

### JSON-RPC 2.0
- `POST /rpc` - Execute JSON-RPC call
- `GET /rpc/methods` - List available methods

### MCP Protocol
- `GET /.well-known/mcp.json` - MCP manifest
- `POST /mcp` - MCP JSON-RPC endpoint
- `GET /mcp/tools` - List available tools

### JSON-LD
- `GET /context` - JSON-LD vocabulary context

### Info
- `GET /` - API information

## JSON-RPC Request Format

```json
{
  "jsonrpc": "2.0",
  "method": "service.action",
  "params": { ... },
  "id": 1,
  "@context": "https://api.magentic.market/context"
}
```

## Services

Routes to these downstream services:
- `context` - at-context (auth/permissions)
- `identity` - magentic-id (identity registry)
- `mail` - magentic-mail (messaging)
- `rubygems` - magentic-rubygems (gem registry)
- `github` - magentic-github (git hosting)
- `host` - magentic-host (app deployment)

## Usage in Host App

```ruby
# Gemfile
gem "json-rpc-ld", git: "https://github.com/laquereric/json-rpc-ld.git", require: "json_rpc_ld"
gem "mcp-skill-sot", git: "https://github.com/laquereric/mcp-skill-sot.git"

# config/routes.rb
mount JsonRpcLd::Engine, at: "/api"
mount McpSkillSot::Engine, at: "/admin"
```
