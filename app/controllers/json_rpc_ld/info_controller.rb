module JsonRpcLd
  class InfoController < ApplicationController
    def show
      render json: {
        name: "Magentic Market API",
        version: JsonRpcLd::VERSION,
        protocol: "JSON-RPC 2.0",
        context: "https://api.magentic.market/context",
        endpoints: {
          rpc: "POST /rpc",
          methods: "GET /rpc/methods",
          context: "GET /context",
          health: "GET /up"
        },
        services: %w[context identity mail rubygems github host],
        documentation: "https://magentic.market/docs/api"
      }
    end
  end
end
