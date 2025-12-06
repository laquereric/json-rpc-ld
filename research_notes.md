# JSON-RPC-LD Research Notes

## jsonrpc.org Website Design Observations

### Visual Design
- Dark header with "JSON-RPC" branding
- Left sidebar navigation with sections:
  - SPECS (2.0, 1.0)
  - MORE DETAILS (What is JSON?, What is RPC?, 1.0 vs. 2.0, Implementations, Join the Discussion, What uses JSON-RPC)
  - TRANSLATIONS
  - SOCIAL
- Main content area with large heading and tagline
- Clean, simple layout
- Light gray/white background for main content
- Green numbered boxes on sidebar links

### Content Structure
- Homepage with tagline: "A light weight remote procedure call protocol. It is designed to be simple!"
- Navigation to specification versions
- Educational content sections
- Implementation resources

### Technology Stack
- Need to inspect source to determine exact tech stack

## Source Specifications to Review

### JSON-RPC
- URL: https://www.jsonrpc.org/specification
- Version 2.0 specification

### JSON-LD
- URL: https://json-ld.org/
- W3C standard for linked data

### SHACL
- URL: https://www.w3.org/TR/shacl/
- Shapes Constraint Language for RDF validation

## Website Technology Stack (jsonrpc.org)

Based on source inspection, the website uses:
- **Bootstrap** (CSS framework) - bootstrap.css and bootstrap-responsive.css
- **Static HTML** - Simple HTML pages with no complex JavaScript framework
- **Fixed navbar** with dark styling (navbar-fixed-top)
- **Sidebar navigation** using Bootstrap's well and nav-list components
- **Responsive design** with Bootstrap grid system (span3 for sidebar, span9 for content)
- **Google Analytics** for tracking

## JSON-RPC 2.0 Key Specifications

### Request Object Members
- `jsonrpc`: String, MUST be exactly "2.0"
- `method`: String, name of method to invoke
- `params`: Structured value (Array or Object), MAY be omitted
- `id`: String, Number, or NULL identifier

### Response Object Members
- `jsonrpc`: String, MUST be exactly "2.0"
- `result`: REQUIRED on success, determined by method
- `error`: REQUIRED on error, Object with code/message/data
- `id`: MUST match Request id, or Null on parse error

### Error Object
- `code`: Number (integer) indicating error type
- `message`: String, concise description
- `data`: Optional additional information

### Error Codes
- -32700: Parse error
- -32600: Invalid Request
- -32601: Method not found
- -32602: Invalid params
- -32603: Internal error
- -32000 to -32099: Server error (implementation-defined)

### Key References
- RFC 4627 (JSON specification)
- RFC 2119 (Key words for requirements)
- Origin: 2010-03-26, Updated: 2013-01-04
- Author: JSON-RPC Working Group

## JSON-LD Key Concepts

JSON-LD is a lightweight Linked Data format that adds semantic meaning to JSON.

### Core Features
- **@context**: Defines how terms map to IRIs (vocabularies)
- **@id**: Unique identifier for the object (IRI)
- **@type**: Type of the object
- Based on successful JSON format
- Enables JSON data to interoperate at Web-scale
- W3C Recommendation (16 January 2014)

### Example Structure
```json
{
  "@context": "https://json-ld.org/contexts/person.jsonld",
  "@id": "http://dbpedia.org/resource/John_Lennon",
  "name": "John Lennon",
  "born": "1940-10-09",
  "spouse": "http://dbpedia.org/resource/Cynthia_Lennon"
}
```

### Key References
- W3C JSON-LD 1.1 Specification
- JSON-LD Community Group
- W3C Recommendation status

## SHACL Key Concepts

SHACL (Shapes Constraint Language) validates RDF graphs against conditions.

### Core Concepts
- **Shapes Graph**: RDF graph containing validation conditions
- **Data Graph**: RDF graph being validated
- **Shapes**: Define constraints and validation rules
- **Targets**: Define which nodes to validate (targetNode, targetClass, etc.)
- **Constraints**: Validation rules applied to focus nodes
- **Severity**: Violation, Warning, or Info

### Key Features
- SHACL Core: Basic constraint language
- SHACL-SPARQL: Advanced SPARQL-based constraints
- Syntax: RDF (Turtle, JSON-LD, RDF/XML)
- W3C Recommendation (20 July 2017)

### Key References
- W3C SHACL Recommendation: https://www.w3.org/TR/shacl/
- Editors: Holger Knublauch (TopQuadrant), Dimitris Kontokostas (University of Leipzig)
