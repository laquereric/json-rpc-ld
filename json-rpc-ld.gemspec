require_relative "lib/json_rpc_ld/version"

Gem::Specification.new do |spec|
  spec.name        = "json-rpc-ld"
  spec.version     = JsonRpcLd::VERSION
  spec.authors     = ["Eric Laquer"]
  spec.summary     = "JSON-RPC 2.0 API gateway with JSON-LD context"
  spec.description = "A mountable Rails engine providing a unified JSON-RPC 2.0 gateway with Linked Data context support for the Magentic Market ecosystem."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/laquereric/json-rpc-ld"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile"]
  end

  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "mcp-skill-sot"
end
