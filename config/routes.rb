JsonRpcLd::Engine.routes.draw do
  # MCP Protocol endpoints
  get ".well-known/mcp.json", to: "mcp#manifest"
  post "mcp", to: "mcp#call"
  get "mcp/tools", to: "mcp#tools"

  # JSON-LD Context
  get "context", to: "context#show"

  # JSON-RPC 2.0 endpoint
  post "rpc", to: "rpc#call"

  # List available methods
  get "rpc/methods", to: "rpc#methods"

  # Root shows API info
  root to: "info#show"
end
