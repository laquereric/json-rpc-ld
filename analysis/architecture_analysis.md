# JSON-RPC-LD Architecture Analysis

## Executive Summary

JSON-RPC-LD represents a sophisticated integration of three established W3C and community standards: JSON-RPC 2.0, JSON-LD 1.1, and SHACL. The architecture addresses a fundamental limitation in traditional RPC protocols by adding semantic meaning and validation capabilities to remote procedure calls, transforming loosely-typed RPC into a semantically-rich, validated communication protocol.

## Core Architecture

### Three-Layer Integration Model

The JSON-RPC-LD architecture operates through a three-layer integration model that combines complementary standards:

**Layer 1: JSON-RPC 2.0 Foundation**

JSON-RPC 2.0 provides the transport and invocation mechanism. This layer handles the fundamental RPC operations including method invocation, parameter passing, response handling, and error reporting. The protocol maintains its characteristic simplicity with a minimal message structure consisting of `jsonrpc`, `method`, `params`, `id`, and `result` or `error` fields. JSON-RPC-LD preserves complete backward compatibility with this foundation while extending it with semantic capabilities.

**Layer 2: JSON-LD Semantic Enhancement**

JSON-LD 1.1 adds semantic meaning through the mandatory `@context` member. This layer transforms JSON data from simple key-value structures into Linked Data by mapping terms to globally unique IRIs (Internationalized Resource Identifiers). The `@context` mechanism enables data to be interpreted unambiguously across different systems and organizations. Additional JSON-LD features include `@id` for unique identification, `@type` for type specification, and the ability to reference external vocabularies and ontologies.

**Layer 3: SHACL Validation Framework**

SHACL provides the validation and constraint definition layer. This enables servers to publish machine-readable schemas that define the expected structure, types, cardinality, and value constraints for both request parameters and response results. SHACL shapes serve multiple purposes: runtime validation, documentation generation, client code generation, and contract verification.

### Mandatory Context Requirement

A critical architectural decision in JSON-RPC-LD is the mandatory inclusion of `@context` in all `params` and `result` objects. This requirement fundamentally distinguishes JSON-RPC-LD from standard JSON-RPC and has several important implications:

**Semantic Explicitness**: Every data element exchanged through JSON-RPC-LD must have explicit semantic meaning. This eliminates ambiguity and reduces the risk of misinterpretation between client and server implementations.

**No Unconstrained Interoperability**: The specification explicitly states that JSON-RPC and JSON-RPC-LD are interoperable only to the degree that applications accommodate that feature. JSON-RPC-LD itself does not allow any unconstrained data types. This is a deliberate design choice that prioritizes semantic clarity and type safety over universal compatibility.

**Contract-First Design**: The mandatory context encourages a contract-first approach to API design where semantic contracts are defined before implementation, similar to how OpenAPI or gRPC schemas work but with the added benefit of global semantic interoperability.

## json-rpc-ld_codegen Architecture

### Design Philosophy

The json-rpc-ld_codegen family represents a code generation approach that embodies the principle of "semantic contracts as code." The architecture is designed around several core principles:

**Validation at Boundaries**: Both inbound and outbound data must be validated against SHACL shapes. This ensures that contracts are enforced at every interaction point, preventing invalid data from entering or leaving the system.

**No Unconstrained Interoperability**: The codegen tools explicitly do not support standard JSON-RPC without semantic constraints. This is a deliberate architectural choice that maintains semantic integrity and prevents degradation to loosely-typed RPC.

**Language-Specific Type Systems**: Each language implementation leverages the native type system of the target language, providing compile-time safety where possible.

### Multi-Language Implementation Strategy

The json-rpc-ld_codegen family consists of three language-specific implementations, each designed to integrate with the target language's ecosystem:

**json-rpc-ld_codegen_ruby**

The Ruby implementation supports Sorbet, a gradual type checker for Ruby. This integration provides static type checking capabilities in a traditionally dynamic language. The architecture likely generates Ruby classes with Sorbet type annotations (using `sig` blocks) that correspond to SHACL shapes. The generated code would include:

- Type-annotated method signatures for RPC methods
- Validation logic that checks SHACL constraints at runtime
- Serialization/deserialization with JSON-LD context handling
- Integration with Ruby's metaprogramming capabilities for dynamic method dispatch

**json-rpc-ld_codegen_python**

The Python implementation also supports Sorbet, which appears to be a documentation error (likely should be "mypy" or "Pydantic" for Python). The architecture would generate Python code with type hints (PEP 484) and validation logic. Key components would include:

- Type-hinted classes corresponding to SHACL shapes
- Runtime validation using libraries like Pydantic or dataclasses
- JSON-LD context management
- Async/await support for modern Python RPC frameworks
- Integration with Python's type checking ecosystem (mypy, pyright)

**json-rpc-ld_codegen_typescript**

The TypeScript implementation (also listed with Sorbet support, likely another documentation error) would leverage TypeScript's structural type system. The generated code would include:

- TypeScript interfaces and types derived from SHACL shapes
- Runtime validation logic (possibly using libraries like Zod or io-ts)
- JSON-LD context handling
- Integration with modern TypeScript RPC frameworks
- Full IDE support with autocomplete and type checking

### Code Generation Pipeline

The code generation architecture follows a multi-stage pipeline:

**Stage 1: SHACL Shape Parsing**

The generator parses SHACL shapes graphs (in Turtle, JSON-LD, or RDF/XML format) and builds an internal representation of the constraints. This includes:

- Identifying node shapes and property shapes
- Extracting constraint components (datatype, cardinality, value ranges, etc.)
- Resolving references between shapes
- Building a dependency graph of shape relationships

**Stage 2: Type System Mapping**

The internal representation is mapped to the target language's type system:

- SHACL datatypes → language-specific types (xsd:integer → number/int, xsd:string → string, etc.)
- Cardinality constraints → optional/required fields and arrays
- Value constraints → validation rules or refined types
- Class-based shapes → classes/interfaces/structs
- Property paths → nested object structures

**Stage 3: Validation Code Generation**

Validation logic is generated for each shape:

- Inbound validation: Checks incoming RPC parameters before method execution
- Outbound validation: Checks outgoing RPC results before serialization
- Error reporting: Generates detailed validation error messages
- Severity handling: Distinguishes between violations, warnings, and info messages

**Stage 4: RPC Scaffolding Generation**

The generator creates the RPC infrastructure:

- Method stubs for server implementation
- Client proxy classes for method invocation
- JSON-LD context serialization/deserialization
- Error handling and reporting
- Transport layer integration (HTTP, WebSocket, etc.)

### Validation Architecture

The validation architecture is central to json-rpc-ld_codegen and operates at multiple levels:

**Compile-Time Validation** (where supported)

In statically-typed languages like TypeScript, many SHACL constraints can be enforced at compile time through the type system. This includes:

- Required vs. optional properties (sh:minCount)
- Type constraints (sh:datatype, sh:class)
- Enumeration constraints (sh:in)

**Runtime Validation** (always required)

Runtime validation enforces constraints that cannot be checked at compile time:

- Value range constraints (sh:minInclusive, sh:maxExclusive)
- String pattern matching (sh:pattern)
- Complex logical constraints (sh:and, sh:or, sh:not)
- Cross-property constraints (sh:equals, sh:lessThan)
- Custom SPARQL-based constraints

**Bidirectional Validation**

Both inbound (request parameters) and outbound (response results) data are validated:

- **Inbound validation** protects the server from malformed requests and ensures that business logic receives valid data
- **Outbound validation** ensures that the server produces valid responses and catches implementation errors before they reach clients

### Error Handling Architecture

The error handling architecture integrates JSON-RPC 2.0 error codes with SHACL validation results:

**Validation Failure Mapping**

SHACL validation failures are mapped to JSON-RPC error responses:

- Invalid request structure → JSON-RPC error code -32600 (Invalid Request)
- Invalid parameter types/values → JSON-RPC error code -32602 (Invalid params)
- Server-side validation failures → JSON-RPC error code -32603 (Internal error)

**Detailed Error Information**

The error response includes detailed SHACL validation information in the error data field:

- Focus node: The specific data element that failed validation
- Result path: The property path where the violation occurred
- Constraint component: Which SHACL constraint was violated
- Expected vs. actual values
- Human-readable error messages

## Integration with Existing Ecosystems

### JSON-LD Ecosystem Integration

JSON-RPC-LD integrates with the broader JSON-LD ecosystem:

**Vocabulary Reuse**: Applications can reference existing vocabularies like Schema.org, FOAF, Dublin Core, etc., promoting semantic interoperability.

**Context Sharing**: JSON-LD contexts can be published and reused across multiple APIs, creating consistent semantic conventions.

**RDF Compatibility**: JSON-RPC-LD messages can be converted to RDF triples, enabling integration with RDF databases, SPARQL endpoints, and semantic reasoning systems.

### SHACL Ecosystem Integration

The SHACL integration provides several benefits:

**Shape Reuse**: SHACL shapes can be shared across multiple APIs and even between JSON-RPC-LD and other RDF-based systems.

**Validation Tool Compatibility**: Existing SHACL validation engines can be used to validate JSON-RPC-LD messages.

**Shape Evolution**: SHACL shapes can evolve over time with versioning strategies, supporting API evolution.

### Development Tool Integration

The code generation approach enables rich development tool integration:

**IDE Support**: Generated types provide autocomplete, inline documentation, and type checking in modern IDEs.

**API Documentation**: SHACL shapes serve as machine-readable API documentation that can be rendered into human-readable formats.

**Testing Tools**: Generated validation code can be used in testing frameworks to ensure API compliance.

**Contract Testing**: SHACL shapes enable consumer-driven contract testing where clients and servers can verify compatibility.

## Architectural Benefits

### Type Safety Without Tight Coupling

JSON-RPC-LD achieves type safety through semantic contracts rather than language-specific type systems. This provides several advantages:

**Language Independence**: Semantic contracts are language-agnostic, enabling polyglot architectures where clients and servers use different programming languages.

**Loose Coupling**: Systems are coupled through semantic contracts rather than implementation details, making it easier to evolve systems independently.

**Global Interoperability**: Using IRIs for semantic definitions enables interoperability at web scale, not just within a single organization.

### Documentation as Code

SHACL shapes serve as executable documentation:

**Always Up-to-Date**: Generated code is always synchronized with the SHACL shapes, eliminating documentation drift.

**Machine-Readable**: SHACL shapes can be processed by tools for documentation generation, testing, and validation.

**Human-Readable**: SHACL shapes can be rendered into human-readable documentation with examples and descriptions.

### Validation at Design Time

The code generation approach moves validation from runtime to design time:

**Early Error Detection**: Many errors are caught during code generation or compilation rather than at runtime.

**Reduced Testing Burden**: Validation logic is generated and tested once rather than implemented manually in each application.

**Consistent Validation**: All implementations use the same validation logic derived from SHACL shapes, ensuring consistency.

## Architectural Challenges and Considerations

### Complexity Trade-offs

JSON-RPC-LD introduces additional complexity compared to standard JSON-RPC:

**Learning Curve**: Developers must understand JSON-LD, SHACL, and RDF concepts in addition to JSON-RPC.

**Tooling Requirements**: Code generation tools must be integrated into the development workflow.

**Performance Overhead**: Validation and JSON-LD processing add computational overhead compared to simple JSON parsing.

### Semantic Modeling Challenges

Effective use of JSON-RPC-LD requires thoughtful semantic modeling:

**Vocabulary Selection**: Choosing appropriate vocabularies and IRIs requires understanding of semantic web best practices.

**Shape Design**: Designing SHACL shapes that are both expressive and maintainable requires expertise.

**Evolution Management**: Evolving semantic contracts while maintaining backward compatibility requires careful planning.

### Ecosystem Maturity

The JSON-RPC-LD ecosystem is still emerging:

**Limited Tooling**: Compared to mature RPC frameworks like gRPC or OpenAPI, JSON-RPC-LD tooling is less developed.

**Community Size**: The community around JSON-RPC-LD is smaller than mainstream RPC technologies.

**Best Practices**: Best practices for JSON-RPC-LD development are still being established.

## Future Architectural Directions

### Enhanced Code Generation Capabilities

Future versions of json-rpc-ld_codegen could include:

**Multi-Language Interoperability**: Generating client code in one language and server code in another from the same SHACL shapes.

**Framework Integration**: Tight integration with popular RPC frameworks (Express, FastAPI, Rails, etc.).

**Advanced Type Features**: Leveraging advanced type system features like dependent types, refinement types, and effect systems.

### Semantic Reasoning Integration

Integration with semantic reasoning could enable:

**Automatic Contract Validation**: Using reasoning to verify that SHACL shapes are consistent and complete.

**Semantic API Discovery**: Discovering compatible APIs based on semantic similarity of their contracts.

**Intelligent Client Generation**: Generating clients that can adapt to API changes through semantic understanding.

### Performance Optimization

Performance optimizations could include:

**Compiled Validation**: Compiling SHACL shapes to optimized validation code.

**Caching Strategies**: Caching parsed contexts and shapes for improved performance.

**Streaming Validation**: Validating large messages in a streaming fashion to reduce memory usage.

## Conclusion

The JSON-RPC-LD architecture represents a thoughtful integration of semantic web technologies with remote procedure call protocols. The json-rpc-ld_codegen family extends this architecture with code generation capabilities that bring semantic contracts into the development workflow, providing type safety, validation, and documentation benefits. While the architecture introduces additional complexity, it offers significant advantages for systems that require semantic interoperability, strong contracts, and polyglot architectures. The success of JSON-RPC-LD will depend on the maturity of tooling, the growth of the community, and the establishment of best practices for semantic API design.
