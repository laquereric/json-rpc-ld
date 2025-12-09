import { cn } from "@/lib/utils";
import { Link, useLocation } from "wouter";

interface LayoutProps {
  children: React.ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const [location] = useLocation();

  const isActive = (path: string) => location === path;

  return (
    <div className="min-h-screen bg-background font-sans text-foreground flex flex-col">
      {/* Fixed Navbar */}
      <header className="fixed top-0 left-0 right-0 h-[60px] bg-[#222] text-white z-50 flex items-center shadow-md">
        <div className="container mx-auto px-4 flex items-center justify-between">
          <div className="flex items-center gap-8">
            <Link href="/" className="text-xl font-bold tracking-tight hover:text-gray-200 transition-colors">
              JSON-RPC-LD
            </Link>
            <nav className="hidden md:flex items-center gap-6 text-sm font-medium">
              <Link href="/" className={cn("hover:text-white transition-colors", isActive("/") ? "text-white" : "text-gray-400")}>
                Home
              </Link>
              <Link href="/specification" className={cn("hover:text-white transition-colors", isActive("/specification") ? "text-white" : "text-gray-400")}>
                Specification
              </Link>
            </nav>
          </div>
        </div>
      </header>

      {/* Main Content Area with Sidebar */}
      <div className="container mx-auto px-4 pt-[90px] pb-12 flex-1">
        <div className="flex flex-col md:flex-row gap-8">
          {/* Sidebar */}
          <aside className="w-full md:w-64 flex-shrink-0">
            <div className="bg-gray-50 border border-gray-200 rounded-sm p-4 sticky top-[90px]">
              <nav className="space-y-6">
                <div>
                  <h3 className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 px-2">Specs</h3>
                  <ul className="space-y-1">
                    <li>
                      <Link href="/specification" className={cn("block px-2 py-1.5 text-sm rounded-sm transition-colors", isActive("/specification") ? "bg-accent text-white font-medium" : "text-gray-700 hover:bg-gray-100")}>
                        JSON-RPC-LD 1.0
                      </Link>
                    </li>
                    <li>
                      <a href="https://www.jsonrpc.org/specification" target="_blank" rel="noopener noreferrer" className="block px-2 py-1.5 text-sm text-gray-700 hover:bg-gray-100 rounded-sm transition-colors">
                        JSON-RPC 2.0 ↗
                      </a>
                    </li>
                  </ul>
                </div>

                <div>
                  <h3 className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2 px-2">More Details</h3>
                  <ul className="space-y-1">
                    <li>
                      <a href="https://json-ld.org/" target="_blank" rel="noopener noreferrer" className="block px-2 py-1.5 text-sm text-gray-700 hover:bg-gray-100 rounded-sm transition-colors">
                        What is JSON-LD? ↗
                      </a>
                    </li>
                    <li>
                      <a href="https://www.w3.org/TR/shacl/" target="_blank" rel="noopener noreferrer" className="block px-2 py-1.5 text-sm text-gray-700 hover:bg-gray-100 rounded-sm transition-colors">
                        What is SHACL? ↗
                      </a>
                    </li>
                  </ul>
                </div>
              </nav>
            </div>
          </aside>

          {/* Main Content */}
          <main className="flex-1 min-w-0">
            {children}
          </main>
        </div>
      </div>

      {/* Footer */}
      <footer className="border-t border-gray-200 py-8 mt-auto bg-gray-50">
        <div className="container mx-auto px-4 text-center text-sm text-gray-500">
          <p>JSON-RPC-LD is a proposed extension to JSON-RPC 2.0.</p>
          <p className="mt-2">Designed to be simple, structured, and semantic.</p>
        </div>
      </footer>
    </div>
  );
}
