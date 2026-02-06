module JsonRpcLd
  class ContextController < ApplicationController
    def show
      render json: jsonld_context, content_type: "application/ld+json"
    end

    private

    def jsonld_context
      {
        "@context" => {
          "@vocab" => "https://api.magentic.market/vocab#",
          "magentic" => "https://magentic.market/ns#",
          "schema" => "https://schema.org/",
          "xsd" => "http://www.w3.org/2001/XMLSchema#",

          # Identity types
          "User" => "magentic:User",
          "Agent" => "magentic:Agent",
          "Identity" => "magentic:Identity",

          # Permission types
          "Permission" => "magentic:Permission",
          "Delegation" => "magentic:Delegation",

          # Service types
          "Gem" => "magentic:Gem",
          "Repository" => "magentic:Repository",
          "Message" => "magentic:Message",
          "Application" => "magentic:Application",

          # Common properties
          "id" => "@id",
          "type" => "@type",
          "handle" => "magentic:handle",
          "displayName" => "schema:name",
          "email" => "schema:email",
          "avatarUrl" => "schema:image",
          "bio" => "schema:description",
          "verified" => { "@id" => "magentic:verified", "@type" => "xsd:boolean" },
          "createdAt" => { "@id" => "schema:dateCreated", "@type" => "xsd:dateTime" },
          "updatedAt" => { "@id" => "schema:dateModified", "@type" => "xsd:dateTime" },

          # Relationships
          "owner" => { "@id" => "magentic:owner", "@type" => "@id" },
          "agent" => { "@id" => "magentic:agent", "@type" => "@id" },
          "permission" => { "@id" => "magentic:permission", "@type" => "@id" },

          # Actions
          "resource" => "magentic:resource",
          "action" => "magentic:action",
          "grantedAt" => { "@id" => "magentic:grantedAt", "@type" => "xsd:dateTime" },
          "expiresAt" => { "@id" => "magentic:expiresAt", "@type" => "xsd:dateTime" }
        }
      }
    end
  end
end
