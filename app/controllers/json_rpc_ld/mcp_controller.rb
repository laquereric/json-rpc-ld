module JsonRpcLd
  class McpController < ApplicationController
    # GET /.well-known/mcp.json
    def manifest
      render json: {
        name: "magentic-market",
        version: JsonRpcLd::VERSION,
        description: "Magentic Market unified MCP gateway",
        tools: tool_schemas,
        protocol: "2024-11-05"
      }
    end

    # GET /mcp/tools
    def tools
      render json: {
        jsonrpc: "2.0",
        result: { tools: tool_schemas },
        id: nil
      }
    end

    # POST /mcp (MCP JSON-RPC endpoint)
    def call
      request_body = JSON.parse(request.body.read)

      method = request_body["method"]
      params = request_body["params"] || {}
      request_id = request_body["id"]

      result = case method
      when "tools/list"
        { tools: tool_schemas }
      when "tools/call"
        execute_tool(params["name"], params["arguments"])
      when "initialize"
        { protocolVersion: "2024-11-05", serverInfo: server_info }
      else
        return render json: error_response(request_id, -32601, "Method not found")
      end

      render json: success_response(request_id, result)
    rescue JSON::ParserError
      render json: error_response(nil, -32700, "Parse error")
    rescue => e
      Rails.logger.error("MCP error: #{e.message}")
      render json: error_response(request_body&.dig("id"), -32603, "Internal error")
    end

    private

    def tool_schemas
      McpSkillSot::Skill.includes(:mcp).where(status: "active").map do |skill|
        {
          name: "#{skill.mcp.name}.#{skill.name}",
          description: skill.description || "#{skill.name} operation",
          inputSchema: skill_input_schema(skill)
        }
      end
    end

    def skill_input_schema(skill)
      skill.parsed_input_schema
    end

    def execute_tool(tool_name, arguments)
      service_name, action = tool_name.split(".", 2)

      skill = McpSkillSot::Skill.includes(:mcp)
        .where(mcp: { name: service_name }, name: action, status: "active")
        .first

      return { error: "Tool not found: #{tool_name}" } unless skill

      route_to_service(skill.mcp, action, arguments || {})
    end

    def route_to_service(mcp, action, params)
      uri = URI.parse("#{mcp.endpoint}/api/v1/rpc")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 30

      req = Net::HTTP::Post.new(uri.path)
      req["Content-Type"] = "application/json"
      req["Authorization"] = request.headers["Authorization"]
      req.body = { action: action, params: params }.to_json

      response = http.request(req)
      JSON.parse(response.body)
    rescue => e
      { error: e.message }
    end

    def server_info
      { name: "magentic-market", version: JsonRpcLd::VERSION }
    end

    def success_response(id, result)
      { jsonrpc: "2.0", result: result, id: id }
    end

    def error_response(id, code, message)
      { jsonrpc: "2.0", error: { code: code, message: message }, id: id }
    end
  end
end
