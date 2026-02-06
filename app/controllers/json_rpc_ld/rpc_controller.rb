module JsonRpcLd
  class RpcController < ApplicationController
    # JSON-RPC 2.0 endpoint with Linked Data context support

    FALLBACK_SERVICES = {
      "context" => { url: ENV.fetch("AT_CONTEXT_URL", "http://localhost:3001") },
      "identity" => { url: ENV.fetch("MAGENTIC_ID_URL", "http://localhost:3002") },
      "mail" => { url: ENV.fetch("MAGENTIC_MAIL_URL", "http://localhost:3003") },
      "rubygems" => { url: ENV.fetch("MAGENTIC_RUBYGEMS_URL", "http://localhost:3004") },
      "github" => { url: ENV.fetch("MAGENTIC_GITHUB_URL", "http://localhost:3005") },
      "host" => { url: ENV.fetch("MAGENTIC_HOST_URL", "http://localhost:3006") }
    }.freeze

    def call
      request_body = JSON.parse(request.body.read)

      if request_body.is_a?(Array)
        results = request_body.map { |req| process_request(req) }
        render json: results
      else
        result = process_request(request_body)
        render json: result
      end
    rescue JSON::ParserError
      render json: error_response(nil, -32700, "Parse error")
    end

    def methods
      render json: {
        jsonrpc: "2.0",
        result: { methods: available_methods },
        id: nil
      }
    end

    private

    def process_request(req)
      unless req["jsonrpc"] == "2.0"
        return error_response(req["id"], -32600, "Invalid Request: jsonrpc must be '2.0'")
      end

      method = req["method"]
      params = req["params"] || {}
      request_id = req["id"]
      context = req["@context"]

      unless method.present?
        return error_response(request_id, -32600, "Invalid Request: method required")
      end

      service_name, action = method.split(".", 2)

      unless service_name && action
        return error_response(request_id, -32601, "Method not found: use 'service.action' format")
      end

      service = find_service(service_name)
      unless service
        return error_response(request_id, -32601, "Service not found: #{service_name}")
      end

      begin
        result = route_to_service(service, action, params, request.headers["Authorization"])
        success_response(request_id, result, context)
      rescue ServiceError => e
        error_response(request_id, e.code, e.message, e.data)
      rescue => e
        Rails.logger.error("RPC error: #{e.message}")
        error_response(request_id, -32603, "Internal error")
      end
    end

    def route_to_service(service, action, params, auth_header)
      uri = URI.parse("#{service[:url]}/api/v1/rpc")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 30

      req = Net::HTTP::Post.new(uri.path)
      req["Content-Type"] = "application/json"
      req["Authorization"] = auth_header if auth_header
      req.body = { action: action, params: params }.to_json

      response = http.request(req)

      case response.code.to_i
      when 200..299
        JSON.parse(response.body)
      when 404
        raise ServiceError.new(-32601, "Method not found: #{action}")
      when 401, 403
        raise ServiceError.new(-32603, "Unauthorized")
      else
        raise ServiceError.new(-32603, "Service error: #{response.code}")
      end
    rescue Errno::ECONNREFUSED
      raise ServiceError.new(-32603, "Service unavailable: #{service[:url]}")
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ServiceError.new(-32603, "Service timeout")
    end

    def success_response(id, result, context = nil)
      response = { jsonrpc: "2.0", result: result, id: id }
      response["@context"] = context_url if context
      response
    end

    def error_response(id, code, message, data = nil)
      response = { jsonrpc: "2.0", error: { code: code, message: message }, id: id }
      response[:error][:data] = data if data
      response
    end

    def context_url
      "https://api.magentic.market/context"
    end

    def find_service(service_name)
      mcp = McpSkillSot::Mcp.find_by(name: service_name, status: "active")
      return { url: mcp.endpoint } if mcp

      FALLBACK_SERVICES[service_name]
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
      FALLBACK_SERVICES[service_name]
    end

    def available_methods
      McpSkillSot::Skill.includes(:mcp)
        .where(status: "active")
        .map { |s| "#{s.mcp.name}.#{s.name}" }
    rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
      FALLBACK_SERVICES.keys.flat_map do |service|
        case service
        when "context"
          ["context.register", "context.authorize", "context.delegate"]
        when "identity"
          ["identity.lookup", "identity.search", "identity.update"]
        when "mail"
          ["mail.send", "mail.inbox", "mail.read"]
        when "rubygems"
          ["rubygems.push", "rubygems.yank", "rubygems.search"]
        when "github"
          ["github.create", "github.clone", "github.list"]
        when "host"
          ["host.deploy", "host.status", "host.logs"]
        else
          []
        end
      end
    end

    class ServiceError < StandardError
      attr_reader :code, :data

      def initialize(code, message, data = nil)
        super(message)
        @code = code
        @data = data
      end
    end
  end
end
