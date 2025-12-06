import Layout from "@/components/Layout";
import { Button } from "@/components/ui/button";
import { ArrowRight, FileText, Network, Share2 } from "lucide-react";
import { Link } from "wouter";

export default function Home() {
  return (
    <Layout>
      <div className="space-y-16">
        {/* Hero Section */}
        <section className="relative overflow-hidden rounded-sm bg-gray-50 border border-gray-100 p-8 md:p-12">
          <div className="absolute top-0 right-0 w-1/2 h-full opacity-10 pointer-events-none">
            <img 
              src="/images/hero-network.png" 
              alt="Network Background" 
              className="w-full h-full object-cover mix-blend-multiply"
            />
          </div>
          
          <div className="relative z-10 max-w-2xl">
            <h1 className="text-5xl md:text-6xl font-bold tracking-tighter text-primary mb-6">
              JSON-RPC-LD
            </h1>
            <p className="text-xl md:text-2xl text-gray-600 font-light leading-relaxed mb-8">
              A lightweight <span className="font-medium text-accent">Linked Data</span> extension for the JSON-RPC 2.0 protocol.
              <br />
              It is designed to be semantic!
            </p>
            <div className="flex flex-wrap gap-4">
              <Link href="/specification">
                <Button size="lg" className="bg-primary text-primary-foreground hover:bg-primary/90 rounded-none h-12 px-8 text-base font-medium">
                  Read the Spec
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
              <a href="https://www.jsonrpc.org/specification" target="_blank" rel="noopener noreferrer">
                <Button variant="outline" size="lg" className="bg-white border-gray-300 text-gray-700 hover:bg-gray-50 rounded-none h-12 px-8 text-base font-medium">
                  Original JSON-RPC 2.0
                </Button>
              </a>
            </div>
          </div>
        </section>

        {/* Features Grid */}
        <section className="grid md:grid-cols-3 gap-8">
          <div className="space-y-4">
            <div className="w-12 h-12 bg-accent/10 flex items-center justify-center rounded-sm">
              <Network className="h-6 w-6 text-accent" />
            </div>
            <h3 className="text-xl font-bold">Linked Data</h3>
            <p className="text-gray-600 leading-relaxed">
              Embed <code>@context</code> directly in your RPC calls to provide semantic meaning to your data, powered by JSON-LD 1.1.
            </p>
          </div>
          
          <div className="space-y-4">
            <div className="w-12 h-12 bg-accent/10 flex items-center justify-center rounded-sm">
              <FileText className="h-6 w-6 text-accent" />
            </div>
            <h3 className="text-xl font-bold">Type Safety</h3>
            <p className="text-gray-600 leading-relaxed">
              Define and validate your API contracts using SHACL shapes, ensuring robust communication between client and server.
            </p>
          </div>
          
          <div className="space-y-4">
            <div className="w-12 h-12 bg-accent/10 flex items-center justify-center rounded-sm">
              <Share2 className="h-6 w-6 text-accent" />
            </div>
            <h3 className="text-xl font-bold">Backward Compatible</h3>
            <p className="text-gray-600 leading-relaxed">
              Fully compatible with existing JSON-RPC 2.0 infrastructure. Add semantic features only where you need them.
            </p>
          </div>
        </section>

        {/* Example Section */}
        <section className="border-t border-gray-200 pt-16">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-3xl font-bold mb-6">A Simple Example</h2>
              <p className="text-gray-600 mb-6 leading-relaxed">
                JSON-RPC-LD adds a <code>@context</code> to the standard JSON-RPC request, allowing parameters to be mapped to global identifiers (IRIs).
              </p>
              <ul className="space-y-3 text-gray-600">
                <li className="flex items-start">
                  <span className="mr-2 text-accent font-bold">✓</span>
                  Standard JSON-RPC 2.0 envelope
                </li>
                <li className="flex items-start">
                  <span className="mr-2 text-accent font-bold">✓</span>
                  JSON-LD context definition
                </li>
                <li className="flex items-start">
                  <span className="mr-2 text-accent font-bold">✓</span>
                  Type mapping with <code>@type</code>
                </li>
              </ul>
            </div>
            
            <div className="bg-[#222] p-6 rounded-sm shadow-lg overflow-hidden relative">
              <div className="absolute top-0 right-0 p-4 opacity-20">
                <img src="/images/texture-grid.png" alt="Grid" className="w-32 h-32 object-contain invert" />
              </div>
              <pre className="font-mono text-sm text-gray-300 overflow-x-auto">
{`{
  "jsonrpc": "2.0",
  "method": "getUser",
  "params": {
    "@context": {
      "User": "http://example.org/User",
      "userId": "http://example.org/User#id"
    },
    "@type": "User",
    "userId": 123
  },
  "id": 1
}`}
              </pre>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  );
}
