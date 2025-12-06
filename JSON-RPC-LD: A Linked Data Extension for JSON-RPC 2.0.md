# JSON-RPC-LD: A Linked Data Extension for JSON-RPC 2.0

## 1. Introduction

This document specifies JSON-RPC-LD, a lightweight extension to the JSON-RPC 2.0 protocol [1] that incorporates the semantic expressiveness of JSON-LD (JSON for Linked Data) [2] and the validation capabilities of the Shapes Constraint Language (SHACL) [3].

JSON-RPC 2.0 is a simple and effective protocol for remote procedure calls. However, it lacks a standardized mechanism for expressing the semantic meaning of the data exchanged between client and server. This can lead to ambiguity and tight coupling between client and server implementations.

JSON-RPC-LD addresses this by introducing an optional mechanism for embedding JSON-LD contexts within JSON-RPC messages. This allows clients and servers to exchange data that is not only structured but also semantically rich and machine-readable. Furthermore, JSON-RPC-LD provides a way for servers to publish SHACL shapes that define the expected structure and types of the data for each method, enabling robust validation and clear documentation.

### 1.1. Conventions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 [4].

This specification is an extension of the JSON-RPC 2.0 specification. All rules and conventions from the JSON-RPC 2.0 specification apply unless explicitly modified by this document.

## 2. JSON-RPC-LD Modifications to JSON-RPC 2.0

JSON-RPC-LD introduces the following modifications to the standard JSON-RPC 2.0 message structure.

### 2.1. The `@context` Member

A JSON-RPC-LD Request or Response object MAY include a `@context` member within the `params` or `result` object, respectively. The value of the `@context` member MUST be a valid JSON-LD context, as defined in the JSON-LD 1.1 specification [2].

When present, the `@context` provides a mapping from the terms used in the `params` or `result` object to IRIs, enabling the data to be interpreted as Linked Data.

### 2.2. SHACL-based Validation

A JSON-RPC-LD server MAY provide a SHACL shapes graph to describe the expected structure and types of the `params` and `result` for each method. This shapes graph can be used by clients for validation and by developers for documentation.

The mechanism for discovering the SHACL shapes graph is not defined in this specification, but it is RECOMMENDED that servers provide a link to the shapes graph in their API documentation.

## 3. Example

Consider a simple JSON-RPC method `getUser` that retrieves information about a user.

### 3.1. JSON-RPC-LD Request

A client can send a JSON-RPC-LD request that includes a `@context` in the `params` object:

```json
{
  "jsonrpc": "2.0",
  "method": "getUser",
  "params": {
    "@context": {
      "id": "@id",
      "User": "http://example.org/User",
      "userId": "http://example.org/User#id"
    },
    "@type": "User",
    "userId": 123
  },
  "id": 1
}
```

### 3.2. JSON-RPC-LD Response

The server can respond with a JSON-RPC-LD response that also includes a `@context`:

```json
{
  "jsonrpc": "2.0",
  "result": {
    "@context": {
      "id": "@id",
      "User": "http://example.org/User",
      "name": "http://xmlns.com/foaf/0.1/name",
      "email": "http://xmlns.com/foaf/0.1/mbox"
    },
    "@id": "http://example.org/users/123",
    "@type": "User",
    "name": "John Doe",
    "email": "john.doe@example.com"
  },
  "id": 1
}
```

### 3.3. SHACL Shapes

The server could provide the following SHACL shapes graph to describe the `getUser` method:

```turtle
@prefix sh: <http://www.w3.org/ns/shacl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix ex: <http://example.org/> .

ex:GetUserParamsShape
  a sh:NodeShape ;
  sh:targetClass ex:User ;
  sh:property [
    sh:path ex:User#id ;
    sh:datatype xsd:integer ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
  ] .

ex:GetUserResultShape
  a sh:NodeShape ;
  sh:targetClass ex:User ;
  sh:property [
    sh:path <http://xmlns.com/foaf/0.1/name> ;
    sh:datatype xsd:string ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
  ] ;
  sh:property [
    sh:path <http://xmlns.com/foaf/0.1/mbox> ;
    sh:datatype xsd:string ;
    sh:minCount 1 ;
    sh:maxCount 1 ;
  ] .
```

## 4. References

[1] [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)

[2] [JSON-LD 1.1](https://www.w3.org/TR/json-ld11/)

[3] [Shapes Constraint Language (SHACL)](https://www.w3.org/TR/shacl/)

[4] [RFC 2119: Key words for use in RFCs to Indicate Requirement Levels](https://www.ietf.org/rfc/rfc2119.txt)
