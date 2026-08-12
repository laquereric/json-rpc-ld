# Portable Local-First Client and JSON-RPC-LD Channel Specification

**Version:** 0.2 (2026-08-12). Adds a normative SHACL shape-file layer under `shapes/cyborg-channel/` as the machine-checkable form of the three-ledger + allow-list constraints. v0.1 was the initial Manus draft. See Appendix S.

**Changelog v0.1 -> v0.2:** the wire constraints in sections 3.3, 4.1, 4.2, 4.3, and 6 are now backed by SHACL shape files -- server validates on ingest, client validates before push, conformance validates fixtures. The sync-intent/patch shapes are `sh:closed`, so the allow-list and the invariant that no server-authoritative or private field crosses are enforced by a standard validator rather than ad-hoc code.

**Status:** Implementation-ready plan for protocol version 1.0  
**Scope:** One invariant Rails API with SQLite; portable local-first client applications in Python, JavaScript, Java, and Rust.  
**Author:** Manus AI

> **Non-negotiable architectural boundary.** There is exactly **one** server implementation: the Rails API backed by SQLite. It owns canonical data, schema migrations, authorization, provenance, and the publication allow-list. A client application is never a server replacement. A client has its own local SQLite database and communicates only through this protocol.

## 1. Purpose, scope, and invariants

This specification defines a language-neutral synchronization channel between a single authoritative Rails API and many independently implemented client applications. The channel is **JSON-RPC 2.0 whose domain payloads are JSON-LD 1.1**. JSON-RPC supplies a compact request/response envelope, named methods, correlation identifiers, and standard error conventions; JSON-LD supplies stable identifiers and a self-describing vocabulary for records. JSON-RPC is transport-agnostic and its request parameters may be named objects, while JSON-LD is specifically designed to add linked-data identifiers and contexts to ordinary JSON representations.[1] [2]

The protocol is intended for a local-first application. Each logical, tool-scoped **StoreFile** has two materializations: its authoritative form in the server database and its local client materialization in the client database. The client does not write server-owned state directly. It moves data through three ledgers with sharply different authority and export rules.

| Invariant | Required consequence |
|---|---|
| One Rails API is authoritative. | Python, JavaScript, Java, and Rust implementations are **clients only**. No language receives its own server, migrations, canonical schema, or authorization policy. |
| Canonical data is server-owned. | A client may cache canonical records locally but treats server-issued versions, tombstones, and provenance as authoritative. |
| A StoreFile has server and client materializations. | The server is the source of truth; the client is a durable local replica plus local-only state. Their databases do not have to share a file format or ORM. |
| Publication is explicit. | Only changes represented as a `SyncIntent` and accepted by the current server allow-list may leave a client. |
| Private local data never crosses the boundary. | `PrivateLocal` records are excluded by schema, query, serializer, network API, logs, diagnostics, and conformance tests. |
| The wire contract—not implementation language—is the integration point. | All clients implement the same JSON-RPC-LD methods, JSON-LD context, cursor behavior, error semantics, and conformance tests. |

The words **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are normative in this document. A *record* is a JSON-LD object that includes both `@context` and `@id`. A *device* is one installed client instance with a revocable credential and a stable device identifier. A *StoreFile* is a logical, tool-scoped store identified by an IRI; it is not a serialized SQLite database file.

## 2. Architecture and authority model

The Rails API exposes one HTTPS JSON-RPC endpoint, here shown as `POST /api/sync/rpc`. The exact path may vary by deployment, but all methods and record shapes below remain unchanged. The server owns the canonical SQLite schema, schema migrations, user and device authorization, provenance, canonical version assignment, and the allow-list. The client owns its local database, sync queue, private data, presentation state, and retry scheduling.

```text
+---------------------+ HTTPS JSON-RPC-LD +-----------------------------+
| Local-first client  | <----------------> | Invariant Rails API         |
|                     |                    |                             |
| local SQLite        | canonical.pull     | canonical SQLite            |
| - canonical cache   | syncIntent.push    | - canonical StoreFiles      |
| - sync_intent queue | channel.negotiate  | - provenance and versions   |
| - private_local     |                    | - policy allow-list          |
+---------------------+                    +-----------------------------+
          |                                                |
          | private_local never serializes                 | server-issued state
          +------------------------------------------------+
```

A client presents an **effective local view** to its user by composing (a) the most recently pulled canonical record, (b) an explicitly visible pending sync-intent overlay, and (c) local-only fields. It MUST label pending state as local and MUST NOT mistake it for canonical confirmation. A canonical record received from the server always supersedes a conflicting cached canonical value.

## 3. Protocol profile

### 3.1 Transport, media type, and JSON-RPC envelope

The channel uses TLS-protected HTTP. Requests use `Content-Type: application/json` and `Accept: application/json`. Each normal call is a JSON-RPC 2.0 request with a non-null string `id`; this allows the client to correlate retries and responses. The outer JSON-RPC envelope is control metadata, not a JSON-LD domain record. Its `params`, successful `result`, and `error.data` values are JSON-LD records and therefore carry `@context` and `@id`.

```json
{
  "jsonrpc": "2.0",
  "id": "call_01J8Y5K6M8H7FQ5CQTNJGN4V2B",
  "method": "channel.negotiate",
  "params": {
    "@context": "https://sync.example.org/context/v1",
    "@id": "urn:uuid:2f23f744-a2b8-4b35-891e-1122241b6b8d",
    "@type": "sf:NegotiationRequest",
    "sf:client": {
      "@id": "urn:app:com.example.task-client:1.4.0"
    },
    "sf:protocolRange": { "sf:min": "1.0", "sf:max": "1.x" }
  }
}
```

The transport MUST reject plaintext HTTP. It SHOULD use HTTP/2 or HTTP/3 where available, although the protocol does not depend on either. JSON-RPC batch envelopes are deliberately **not** part of version 1.0: a request containing multiple JSON-RPC calls can create ordering ambiguity. `syncIntent.push` instead carries an explicit, ordered `sf:intents` array with defined per-intent outcomes. JSON-RPC defines `jsonrpc: "2.0"`, named parameters, a correlated response ID, and its standard parse/request/parameter errors; clients and the server MUST retain those requirements.[1]

| Header | Requirement | Purpose |
|---|---|---|
| `Authorization: Device <opaque-token>` | Required for native clients after enrollment. | Authenticates and scopes a specific device. |
| `X-Request-ID: <UUID>` | Required. | Trace correlation. It MUST contain no user content or private data. |
| `Idempotency-Key: <UUID>` | Required for `syncIntent.push`. | Protects a request retry; the per-intent ID is the durable idempotency key. |
| `X-Channel-Version: 1.0` | Required after negotiation. | Makes accidental protocol downgrade visible. |
| `If-Policy-Epoch: <integer>` | Required for `syncIntent.push`. | Prevents a client from publishing under an obsolete mirrored allow-list. |

A browser client MAY authenticate with a `Secure`, `HttpOnly`, `SameSite` device cookie rather than exposing a bearer token to JavaScript. It MUST then send the deployment's CSRF protection header and use same-origin requests. In either mode, the credential is **not** a ledger record and MUST never appear in JSON-RPC parameters, JSON-LD records, logs, exports, or crash reports.

### 3.2 JSON-LD vocabulary, identifiers, and safe context handling

Each deployment MUST publish an immutable, versioned JSON-LD context such as `https://sync.example.org/context/v1`. The deployment substitutes its own controlled HTTPS namespace; the `example.org` host in this document is illustrative only. The context maps the compact `sf:` terms to stable IRIs, maps `@type` aliases, and declares link-valued fields such as `sf:store`, `sf:target`, and `sf:device` as `@id` values. JSON-LD uses `@context` to map terms to IRIs and `@id` to provide universal identifiers, while retaining JSON compatibility.[2]

A client MUST ship with or cache the exact approved context for every supported protocol version. It MUST NOT dereference arbitrary context URLs supplied by records. An unknown, non-pinned context is a protocol error, not a reason to perform a network fetch. This prevents a record from changing semantic interpretation through an attacker-controlled context.

The following abbreviated context is sufficient to clarify the wire shapes; the deployed context should contain the full, immutable term set.

```json
{
  "@context": {
    "sf": "https://sync.example.org/ns/storefile#",
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "store": { "@id": "sf:store", "@type": "@id" },
    "target": { "@id": "sf:target", "@type": "@id" },
    "device": { "@id": "sf:device", "@type": "@id" },
    "version": { "@id": "sf:version", "@type": "xsd:integer" },
    "updatedAt": { "@id": "sf:updatedAt", "@type": "xsd:dateTime" },
    "baseVersion": { "@id": "sf:baseVersion", "@type": "xsd:integer" }
  }
}
```

Records MUST use stable absolute IRIs or URNs in `@id`. A resource identifier is server-assigned for newly created canonical resources unless the negotiated schema explicitly declares a client-assigned identifier profile. Intent, request, response, patch, and private-record identifiers use client-generated UUID URNs. The protocol does not use JSON `null` to mean “clear a published field”; an allowed `remove` operation represents deletion. This avoids ambiguity during JSON-LD processing, where `null` values have special omission semantics.[2]

### 3.3 Common record envelope

> **SHACL (v0.2):** `shapes/cyborg-channel/envelope.shacl.ttl` (cyb:EnvelopeShape, cyb:ProvenanceShape).

All domain records—including request parameter records, result records, canonical records, `SyncIntent` records, private records, patch records, policy records, and structured error records—MUST contain the fields below.

| Field | Type | Requirement |
|---|---|---|
| `@context` | string or approved context array | Required; must be a negotiated, pinned version. |
| `@id` | absolute IRI or UUID URN | Required; unique within the record's resource class. |
| `@type` | string or array | Required for first-class records; identifies the vocabulary type. |
| `sf:store` | IRI object | Required for StoreFile-scoped records. |
| `sf:schemaVersion` | positive integer | Required where the record has StoreFile data semantics. |

An application data record additionally contains `sf:version`, `sf:state`, `sf:updatedAt`, and server-issued `sf:provenance`. The server assigns these properties; a push payload MUST NOT set, alter, or claim them.

## Part A — JSON-RPC-LD channel specification

## 4. Three-ledger model

The three ledgers are separate logical datasets. They may be separate SQLite tables in a single local database, but they MUST remain distinct in schema, access layer, serialization, and test coverage. The server stores canonical data only; `sync_intent` and `private_local` exist only in client storage.

| Ledger | Location | Authority | Permitted contents | Network rule |
|---|---|---|---|---|
| `canonical` | Server SQLite and read-only local replica | Server | Current canonical records, tombstones, server versions, and provenance. | Server → client through `canonical.pull`; server responses may update the local replica. |
| `sync_intent` | Local SQLite only | Client proposes; server decides | Explicit, allow-listed patch records with a target and base canonical version. | Client → server only through `syncIntent.push`. |
| `private_local` | Local SQLite only | Client/user | Drafts, device preferences, UI state, private annotations, unreleased values, secrets references, and local workflow state. | **Never leaves the client.** |

### 4.1 Canonical record shape

> **SHACL (v0.2):** `shapes/cyborg-channel/canonical-record.shacl.ttl` (cyb:CanonicalRecordShape, cyb:CanonicalTombstoneShape).

A canonical record is both a linked-data resource and an authoritative versioned fact. The user-defined fields shown below (`tool:title` and `tool:status`) are examples; the actual allowable entity types and terms are negotiated per StoreFile schema.

```json
{
  "@context": [
    "https://sync.example.org/context/v1",
    "https://sync.example.org/context/task-v3"
  ],
  "@id": "https://api.example.org/storefiles/task-board/records/42",
  "@type": ["sf:CanonicalRecord", "tool:Task"],
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:schemaVersion": 3,
  "sf:version": 1042,
  "sf:state": "active",
  "sf:updatedAt": "2026-08-12T10:15:30Z",
  "sf:provenance": {
    "@context": "https://sync.example.org/context/v1",
    "@id": "urn:provenance:canonical:1042",
    "@type": "sf:Provenance",
    "sf:recordedBy": { "@id": "https://api.example.org/actors/7" },
    "sf:source": "syncIntent.push",
    "sf:device": { "@id": "urn:device:9d2a8bd8-a9c8-4bd7-b1e6-6f40e92671d1" },
    "sf:recordedAt": "2026-08-12T10:15:30Z"
  },
  "tool:title": "Prepare release notes",
  "tool:status": "open"
}
```

A deletion is represented as a canonical tombstone, not a physical absence from a pull page. It retains `@context`, `@id`, StoreFile, schema version, a new canonical version, `sf:state: "deleted"`, and provenance, but omits ordinary application fields. A client MUST upsert a tombstone locally, remove it from active presentation, and retain it at least until the cursor that delivered it has been committed.

### 4.2 Sync-intent record shape

> **SHACL (v0.2):** `shapes/cyborg-channel/sync-intent.shacl.ttl` (cyb:SyncIntentShape + cyb:PatchShape, both sh:closed -- the machine-checkable allow-list/privacy boundary).

A SyncIntent is a durable request to publish a narrow, explicitly allowed change. It is not a claimed canonical record. It MUST carry the canonical version against which the user made the change and an immutable `sf:operationId`. Each patch is itself a JSON-LD record with a UUID URN, so every transport-visible record is self-identifying.

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8",
  "@type": "sf:SyncIntent",
  "sf:operationId": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:schemaVersion": 3,
  "sf:policyEpoch": 18,
  "sf:target": {
    "@id": "https://api.example.org/storefiles/task-board/records/42"
  },
  "sf:baseVersion": 1042,
  "sf:createdAt": "2026-08-12T10:16:04Z",
  "sf:device": {
    "@id": "urn:device:9d2a8bd8-a9c8-4bd7-b1e6-6f40e92671d1"
  },
  "sf:patches": [
    {
      "@context": "https://sync.example.org/context/v1",
      "@id": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8#patch-1",
      "@type": "sf:Patch",
      "sf:op": "replace",
      "sf:path": "/tool:title",
      "sf:value": "Prepare customer release notes"
    }
  ]
}
```

The only valid patch operations in version 1.0 are `add`, `replace`, and `remove`. An allow-list rule specifies which operations are legal for each exact JSON Pointer path and the value profile accepted by `add` and `replace`. A patch MUST name exactly one target field; wildcard paths, arbitrary JSON Patch operation types, executable expressions, and values containing a `@context` are prohibited. The server obtains actor, time, provenance, resulting version, and canonical merge result itself.

### 4.3 Private-local record shape

> **SHACL (v0.2):** `shapes/cyborg-channel/private-local.shacl.ttl` (cyb:PrivateLocalRecordShape, cyb:NoPrivateLocalInTransitShape).

A PrivateLocal record has a local-only identity distinct from its canonical target. Its values may reference a canonical target for presentation, but they are not patch material and may never be converted implicitly into a SyncIntent.

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:7827bf8f-f2d9-49f6-bbad-6710e5f2c6a7",
  "@type": "sf:PrivateLocal",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:target": {
    "@id": "https://api.example.org/storefiles/task-board/records/42"
  },
  "sf:updatedAt": "2026-08-12T10:16:15Z",
  "sf:values": {
    "local:workingNote": "Ask design for a screenshot before publishing.",
    "local:pinned": true
  }
}
```

`sf:values` is a local property bag. The local schema MUST reserve the `local:` namespace for fields that no server policy can authorize. A client MAY provide an explicit user action such as **Publish title**. That action reads the selected public value, validates it against the mirrored policy, and writes a new SyncIntent patch. It does not serialize a PrivateLocal record or copy the entire local property bag.

### 4.4 Local movement rules

The following transition rules make the data boundary enforceable.

| Event | Required local transaction | Prohibited behavior |
|---|---|---|
| `canonical.pull` returns a record or tombstone. | Upsert it into `canonical`; retain its server version and raw validated JSON-LD; advance the cursor only in the same transaction. | Editing canonical fields in place as though a local edit were confirmed. |
| User changes a private preference or note. | Insert or update `private_local` only. | Creating a SyncIntent automatically. |
| User explicitly publishes an allowed field. | Read the current canonical version; validate the exact path/value against cached policy; insert an immutable SyncIntent in `queued` state. | Selecting the value from a broad `private_local` dump, copying provenance/version fields, or creating an intent for a forbidden path. |
| Server accepts an intent. | Mark the intent `accepted`; upsert the returned canonical record if supplied; retain the response for audit. | Deleting related private data unless a separate local retention rule requires it. |
| Server rejects an intent as stale or forbidden. | Mark it `needs_rebase` or `rejected`; preserve the attempted patch locally; reconcile canonical data. | Silently overwriting canonical state, automatically publishing a private field, or retrying the same stale operation forever. |

A client SHOULD present the effective view in this order: canonical record, then a clearly marked pending SyncIntent overlay for the same allowed path, then unrelated local-only fields. Private fields SHOULD occupy dedicated UI areas or names so they cannot be visually confused with server-backed fields.

## 5. Method surface

### 5.1 `channel.negotiate`

This method is mandatory before the first pull, after local schema migration, after policy-expiry, and after a server returns `SCHEMA_INCOMPATIBLE` or `POLICY_STALE`. It selects a mutually supported protocol and StoreFile schema, returns the active allow-list, and sets response limits. It does not mutate canonical state.

**Parameters**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:cf95fb6e-8b2d-4a00-a030-bb8e893846c0",
  "@type": "sf:NegotiationRequest",
  "sf:client": { "@id": "urn:app:org.example.python-reference:0.1.0" },
  "sf:device": { "@id": "urn:device:9d2a8bd8-a9c8-4bd7-b1e6-6f40e92671d1" },
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:protocolRange": { "sf:min": "1.0", "sf:max": "1.x" },
  "sf:supportedSchemas": [
    { "sf:id": "https://sync.example.org/schema/task", "sf:min": 2, "sf:max": 3 }
  ],
  "sf:knownPolicyEpoch": 17
}
```

**Successful result**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:ea83a494-04cd-4ed6-9532-4542d118f32a",
  "@type": "sf:NegotiationResult",
  "sf:protocolVersion": "1.0",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:schema": {
    "@context": "https://sync.example.org/context/v1",
    "@id": "https://sync.example.org/schema/task/v3",
    "@type": "sf:SchemaDescriptor",
    "sf:schemaVersion": 3,
    "sf:hash": "sha256-BASE64URL-OF-CANONICAL-SCHEMA"
  },
  "sf:policy": {
    "@context": "https://sync.example.org/context/v1",
    "@id": "https://api.example.org/storefiles/task-board/policies/18",
    "@type": "sf:PublicationPolicy",
    "sf:epoch": 18,
    "sf:expiresAt": "2026-08-13T10:00:00Z",
    "sf:rules": [
      {
        "@context": "https://sync.example.org/context/v1",
        "@id": "https://api.example.org/storefiles/task-board/policies/18#task-title",
        "@type": "sf:PublicationRule",
        "sf:resourceType": "tool:Task",
        "sf:path": "/tool:title",
        "sf:operations": ["add", "replace", "remove"],
        "sf:valueType": "xsd:string",
        "sf:maxLength": 240
      }
    ]
  },
  "sf:limits": {
    "@context": "https://sync.example.org/context/v1",
    "@id": "urn:limits:task-board:1.0",
    "@type": "sf:ChannelLimits",
    "sf:maxPullRecords": 500,
    "sf:maxPushIntents": 100,
    "sf:maxRequestBytes": 1048576
  },
  "sf:serverTime": "2026-08-12T10:15:00Z"
}
```

The server MUST return only policy rules the authenticated device is authorized to use. The client MUST atomically cache the schema descriptor and `PublicationPolicy` in a local `sync_policy` table, keyed by StoreFile and policy epoch. A client with no compatible schema MUST permit neither push nor local publication generation; it may preserve local private data and report an upgrade requirement.

### 5.2 `canonical.pull`

This method returns a stable initial snapshot or a subsequent ordered change feed. It is the only method that advances a client’s canonical cursor. `sf:cursor` is an opaque, server-signed token; clients MUST store and replay it without parsing, manufacturing, or sharing it across authenticated scopes.

**Parameters**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:99ef3a17-3557-4bd5-b5ca-5cfe129f1725",
  "@type": "sf:CanonicalPullRequest",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:schemaVersion": 3,
  "sf:cursor": null,
  "sf:limit": 250
}
```

`sf:cursor: null` requests an initial snapshot. The server snapshots a StoreFile at a high-water canonical version and returns pages ordered by `(record_id, version)` from that snapshot. Its opaque `sf:nextCursor` carries the snapshot boundary and page position. Once the final snapshot page is consumed, the cursor switches transparently to change-feed mode, which returns mutations strictly after the recorded high-water version. This prevents an item from being skipped or duplicated because it changed during an initial multi-page pull.

**Successful result**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:31c0768f-661c-4867-9ac8-b02718f6f64e",
  "@type": "sf:CanonicalPage",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:fromCursor": null,
  "sf:nextCursor": "v1.eyJzY29wZSI6Ii4uLiJ9.signature",
  "sf:highWaterVersion": 1042,
  "sf:records": [
    {
      "@context": "https://sync.example.org/context/v1",
      "@id": "https://api.example.org/storefiles/task-board/records/42",
      "@type": ["sf:CanonicalRecord", "tool:Task"],
      "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
      "sf:schemaVersion": 3,
      "sf:version": 1042,
      "sf:state": "active",
      "sf:updatedAt": "2026-08-12T10:15:30Z",
      "sf:provenance": {
        "@context": "https://sync.example.org/context/v1",
        "@id": "urn:provenance:canonical:1042",
        "@type": "sf:Provenance",
        "sf:source": "syncIntent.push"
      },
      "tool:title": "Prepare release notes"
    }
  ],
  "sf:hasMore": false,
  "sf:serverTime": "2026-08-12T10:15:31Z"
}
```

`sf:records` contains both active records and tombstones. A result page MUST be applied in one local SQLite transaction: validate all records, upsert only records whose canonical version is greater than or equal to the cached version, record the server time, and commit the returned cursor. If the transaction fails, the client MUST retain the previous cursor and retry the same pull safely.

The server MAY expire cursors after a documented retention interval or after a schema change that makes the cursor unsafe. On `CURSOR_EXPIRED`, the client preserves `sync_intent` and `private_local`, clears only its local canonical cache and cursor for that StoreFile, then starts a fresh snapshot pull.

### 5.3 `syncIntent.push`

This method sends a bounded ordered set of queued SyncIntent records for one StoreFile and one policy epoch. It is the only method through which a client may propose publication. The server validates every intent independently and returns a result in the same order. Version 1.0 does not promise a cross-intent transaction; a client MUST handle partial acceptance.

**Parameters**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:ae977d2c-7a57-4663-9f2e-4aa85cb359e1",
  "@type": "sf:SyncIntentPushRequest",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:schemaVersion": 3,
  "sf:policyEpoch": 18,
  "sf:intents": [
    {
      "@context": "https://sync.example.org/context/v1",
      "@id": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8",
      "@type": "sf:SyncIntent",
      "sf:operationId": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8",
      "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
      "sf:schemaVersion": 3,
      "sf:policyEpoch": 18,
      "sf:target": { "@id": "https://api.example.org/storefiles/task-board/records/42" },
      "sf:baseVersion": 1042,
      "sf:createdAt": "2026-08-12T10:16:04Z",
      "sf:device": { "@id": "urn:device:9d2a8bd8-a9c8-4bd7-b1e6-6f40e92671d1" },
      "sf:patches": [
        {
          "@context": "https://sync.example.org/context/v1",
          "@id": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8#patch-1",
          "@type": "sf:Patch",
          "sf:op": "replace",
          "sf:path": "/tool:title",
          "sf:value": "Prepare customer release notes"
        }
      ]
    }
  ]
}
```

**Successful result**

```json
{
  "@context": "https://sync.example.org/context/v1",
  "@id": "urn:uuid:9929f2ed-631b-44db-94bb-e6f3caf7c9eb",
  "@type": "sf:SyncIntentPushResult",
  "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
  "sf:policyEpoch": 18,
  "sf:outcomes": [
    {
      "@context": "https://sync.example.org/context/v1",
      "@id": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8#outcome",
      "@type": "sf:IntentOutcome",
      "sf:operationId": "urn:uuid:02cf00da-3b50-46c4-809b-7c704f60e1c8",
      "sf:status": "accepted",
      "sf:canonicalRecord": {
        "@context": "https://sync.example.org/context/v1",
        "@id": "https://api.example.org/storefiles/task-board/records/42",
        "@type": ["sf:CanonicalRecord", "tool:Task"],
        "sf:store": { "@id": "https://api.example.org/storefiles/task-board" },
        "sf:schemaVersion": 3,
        "sf:version": 1043,
        "sf:state": "active",
        "sf:updatedAt": "2026-08-12T10:16:06Z",
        "sf:provenance": {
          "@context": "https://sync.example.org/context/v1",
          "@id": "urn:provenance:canonical:1043",
          "@type": "sf:Provenance",
          "sf:source": "syncIntent.push"
        },
        "tool:title": "Prepare customer release notes"
      }
    }
  ]
}
```

The endpoint MAY return only a JSON-RPC error for a malformed batch request. For a well-formed request, it SHOULD return an outcome for every intent even when all intents are rejected. The `sf:status` values are `accepted`, `duplicate`, `rejected`, and `stale`. `duplicate` returns the same recorded outcome as the first submission. `rejected` contains a structured reason but no sensitive server-only data. `stale` includes the current canonical record, allowing the client to reconcile.

### 5.4 Optional enrollment and renewal methods

A usable device-token channel needs a controlled enrollment flow. The protocol therefore reserves two optional methods, without changing the three core synchronization methods: `device.enroll` and `device.renew`. A deployment may instead expose equivalent Rails-authenticated setup endpoints, provided the issued credential and device identity obey this section.

`device.enroll` is called only during an authenticated setup ceremony—such as an existing Rails session, an administrator-issued one-time code, or a platform-native sign-in. It accepts a device record with `@context`, `@id`, client name, platform, and an optional public-key thumbprint. It returns a single opaque, scoped device token, its expiry, and the device’s authorized StoreFile identifiers. The token MUST be displayed or returned only once, must be revocable per device, and must be stored outside ledgers. `device.renew` rotates an unexpired credential and invalidates the old token after a short overlap. Neither method may expose canonical or private records.

## 6. Server validation, allow-list authority, and policy mirroring

> **SHACL (v0.2):** the allow-list is projected per StoreFile as `shapes/cyborg-channel/allowlist.template.shacl.ttl`; the server validates every ingested payload against the shapes in `shapes/cyborg-channel/`, and a client mirrors them read-only to pre-validate. See Appendix S.

The server’s allow-list is final regardless of what a client cached or generated. The server MUST validate, in this order, before any canonical mutation:

1. Authenticate the device and authorize it for the StoreFile and target record.
2. Verify protocol version, schema version, policy epoch, payload size, identifier syntax, and JSON-LD context against the negotiated profile.
3. Look up the operation id for this device. If its digest matches a prior submission, return the recorded outcome; if the id was reused with different bytes, reject `IDEMPOTENCY_KEY_REUSED`.
4. Verify that the target type, exact patch path, operation, and value satisfy the current allow-list.
5. Reject server-owned paths, including identifiers, canonical version, state, provenance, actor, timestamps, schema version, StoreFile, and any unrecognized field.
6. Compare `sf:baseVersion` with the target’s current canonical version. If it differs, return `stale` with current canonical state; do not apply the patch.
7. In one server transaction, apply the allowed patch, assign a new canonical version and provenance, save the recorded outcome, and return the server-created canonical record.

The server MUST use an explicit field allow-list rather than a deny-list. A rule may authorize `replace /tool:title` while every other application field remains prohibited. It MUST reject an unknown path even if the client claims a later schema. It MUST ignore no forbidden field silently; a rejected intent makes client behavior auditable and prevents false local confirmation.

A well-behaved client mirrors the policy only to prevent accidental publication early. Its `PublicationGuard` accepts `(resource_type, path, operation, value, policy_epoch)` and fails closed. It is the **only** code path allowed to construct a SyncIntent. The network client accepts only prevalidated SyncIntent objects, never arbitrary UI state, canonical objects, or PrivateLocal objects. A policy cache miss, expired policy, hash mismatch, or epoch mismatch disables publication until `channel.negotiate` succeeds.

| Policy state in client | Pull | Edit `private_local` | Generate SyncIntent | Push queued intent |
|---|---:|---:|---:|---:|
| Current, verified policy | Allowed | Allowed | Allowed for exact permitted rule | Allowed |
| Policy expired or missing | Allowed | Allowed | Denied | Denied; negotiate first |
| Server says `POLICY_STALE` | Allowed | Allowed | Denied until refreshed | Stop batch, refresh policy |
| Schema incompatible | Allowed only if the client can validate records safely | Allowed | Denied | Denied |

## 7. Cursors, versions, idempotency, and reconciliation

### 7.1 Version and cursor rules

Each StoreFile has a monotonically increasing canonical version sequence. Every create, allowed mutation, or deletion assigns a higher version. The scope is **one StoreFile**, not a global integer. A cursor is opaque, signed, scope-bound to the authenticated principal and StoreFile, and includes sufficient state for snapshot pagination or change-feed continuation. Clients MUST treat it as an opaque byte string.

The client commits a pull page using a local transaction that persists every validated record and the replacement cursor together. It may receive the same canonical record in a push response and later in a pull; the local upsert rule (`replace only if incoming version >= local version`) makes this harmless. The push response never advances the cursor by itself.

### 7.2 Idempotency rules

`sf:operationId` is an immutable UUID URN generated once when a SyncIntent is inserted into local SQLite. It MUST survive application restart, connectivity failures, and retry. The `Idempotency-Key` HTTP header identifies the containing push request, while per-intent operation IDs determine the durable server behavior. The server stores the first request digest and outcome under `(device_id, operation_id)` for at least the maximum offline-retention period, or indefinitely where practical.

A client retries network or 5xx failures with the same operation IDs and exponential backoff with randomized jitter. It MUST NOT create a new intent merely because the response was lost. If a request was accepted but the response lost, a replay returns `duplicate` and the original canonical result.

### 7.3 Conflict and merge semantics

Version 1.0 uses **strict optimistic concurrency with server-canonical precedence**. A client does not perform server-side last-writer-wins. The server accepts an intent only when `sf:baseVersion` matches the target’s current canonical version. On mismatch, the server returns the current canonical record and the intent is marked `needs_rebase` locally.

The client then applies the current canonical record, removes its speculative pending overlay from the confirmed view, and presents an explicit resolution state. It MAY create a **new** intent only after evaluating the current allow-list and a current canonical version. For a straightforward, user-confirmed “set title to X” operation, the UI may offer “apply my change to latest version”; accepting that action creates a new operation ID with the new base version. It MUST retain the prior intent as superseded for local audit. It MUST NOT silently replay a stale set or merge private fields into a public patch.

This rule is intentionally conservative. It makes the statement “server canonical wins” exact, understandable, and testable across every client language.

### 7.4 Error profile

JSON-RPC standard errors retain their published meanings: `-32700` parse error, `-32600` invalid request, `-32601` method not found, `-32602` invalid params, and `-32603` internal error.[1] Application errors use the `-32000` through `-32099` implementation-defined range, with a JSON-LD `error.data` record.

| Error code | Symbol | Client action |
|---:|---|---|
| `-32001` | `UNAUTHENTICATED` | Stop sync; renew or enroll device. Do not discard local data. |
| `-32002` | `FORBIDDEN` | Mark affected intent rejected; do not retry automatically. |
| `-32003` | `SCHEMA_INCOMPATIBLE` | Stop push; negotiate or require client upgrade. |
| `-32004` | `POLICY_STALE` | Stop push; negotiate, revalidate queued intents, then retry only valid ones. |
| `-32005` | `CURSOR_EXPIRED` | Preserve local intent/private ledgers; clear only canonical cache/cursor and snapshot again. |
| `-32006` | `IDEMPOTENCY_KEY_REUSED` | Quarantine the local queue entry; this is a client integrity fault. |
| `-32007` | `RATE_LIMITED` | Honor `retryAfter`; retry with the same operation IDs. |
| `-32008` | `CONTEXT_UNSUPPORTED` | Stop transport and upgrade/pin a compatible context. |

## 8. Client synchronization loop

A client starts a sync cycle at launch, when connectivity returns, after an explicit user refresh, and on a bounded periodic foreground schedule. It MUST serialize local database write transactions; its HTTP calls may be asynchronous but queue status transitions must be transactional.

| Step | Action | Local outcome |
|---:|---|---|
| 1 | Load `sync_state` and test that schema/policy are current. | If absent/stale, negotiate. |
| 2 | Call `canonical.pull` until `hasMore` is false. | Apply each page and cursor atomically. |
| 3 | Revalidate queued intents against the newly mirrored policy and latest cached canonical version. | Mark invalid ones `rejected_local`; mark mismatched base versions `needs_rebase`. |
| 4 | Send a bounded `syncIntent.push` batch of remaining `queued` intents. | Use durable operation IDs and idempotency key. |
| 5 | Apply outcomes transactionally. | Upsert server canonical records; update intent state; preserve private records. |
| 6 | Pull again from the saved cursor. | Collect changes made by other devices and confirm channel continuity. |

A client MAY give the user immediate local feedback, but that feedback must distinguish `queued`, `sending`, `accepted`, `needs rebase`, and `rejected` from `canonical`. It MUST stop after persistent authentication, policy, or schema errors rather than issuing unbounded retries.

## Part B — per-language client implementation guide

## 9. Common local SQLite design

Every client should use the same logical schema, adjusted only for each language’s migration mechanism and SQLite bindings. Values shown as `json` are stored as validated UTF-8 JSON text or a native JSON column abstraction; the protocol does not require SQLite JSON extensions.

| Table | Key columns | Purpose |
|---|---|---|
| `canonical_record` | `(store_id, record_id)`; `version`, `state`, `jsonld`, `updated_at` | Read-only local replica of server canonical records and tombstones. |
| `sync_intent` | `operation_id`; `store_id`, `target_id`, `base_version`, `policy_epoch`, `payload_json`, `status`, `attempts` | Immutable outbound queue and outcome history. |
| `private_local` | `private_id`; `store_id`, `target_id`, `jsonld`, `updated_at` | Local-only record store. No network-facing repository may query this table. |
| `sync_state` | `store_id`; `cursor`, `schema_version`, `schema_hash`, `policy_epoch`, `policy_json`, `last_sync_at` | Checkpoint and mirrored server policy. |
| `intent_outcome` | `operation_id`, `received_at`, `outcome_json` | Durable response evidence for idempotent retries and user-visible resolution. |

Use parameterized SQL, foreign-key constraints where appropriate, and short write transactions. Python’s standard `sqlite3` documentation likewise recommends parameter binding instead of string interpolation for values.[5] The database location and encryption-at-rest strategy are platform concerns; credentials must be placed in the operating-system credential store or browser credential mechanism, never in any ledger table.

The recommended module boundary is identical in every language:

```text
UI / command surface
        |
LocalStore <----- CanonicalRepository (canonical_record only)
        |                  |
        |                  +-- validates pulled server records
        |
PublicationGuard <----- SyncIntentRepository (sync_intent only)
        |                  |
        |                  +-- emits narrow, validated SyncIntent values
        |
RpcClient <----- SyncEngine

PrivateRepository (private_local only) -- no dependency into RpcClient
```

`PrivateRepository` MUST expose no “export all” method to `RpcClient`, `SyncEngine`, telemetry, diagnostics, or generic object serializer. A static type boundary is preferred: the network API should accept `SyncIntentBatch`, not `object`, `Map`, `JsonNode`, or database rows.

### 9.1 Python client

| Concern | Implementation recommendation |
|---|---|
| Local SQLite | Use the standard-library `sqlite3` module and one application-data file such as `storefile-client.db`. The module supplies a DB-API 2.0 interface and opens an on-disk SQLite connection through `sqlite3.connect()`.[5] Enable foreign keys and WAL where supported; use a single writer lock around sync-state changes. |
| JSON-RPC-LD | Use a small typed transport layer over `httpx` or `urllib.request`. Represent immutable JSON-LD records as `TypedDict`/dataclasses plus a strict validator; serialize through `json.dumps` only after `PublicationGuard` validation. |
| Sync loop | Run an `asyncio` foreground task or a single worker thread. Wrap each pull-page application and cursor update in `BEGIN IMMEDIATE`/commit; atomically move queue rows through `queued → sending → accepted/stale/rejected`. |
| Private isolation | Give `PrivateRepository` its own methods and SQL statements. Its record type must not satisfy the `SyncIntent` constructor. Add a test-only outbound HTTP transport that fails if a sentinel private string occurs in a request body. |
| Packaging | Publish a `pyproject.toml` package and an optional CLI using `pipx`, `uv`, or a wheel. Put migrations in the package and use `platformdirs` for the database path. Use the OS credential store through a vetted keyring adapter. |

Python is well suited to a first reference because it has a standard SQLite interface, an uncomplicated JSON stack, and fast fixture-driven testing. `sqlite3` connections and cursor-based transactions are explicitly supported by the standard library documentation.[5]

### 9.2 JavaScript browser client

| Concern | Implementation recommendation |
|---|---|
| Local SQLite | Use the official SQLite Wasm distribution in a dedicated Worker and persist the database in OPFS. OPFS is private to the web origin and is optimized for in-place local file access; synchronous access handles are available in dedicated workers, which matches the SQLite Wasm deployment model.[3] [4] |
| OPFS concurrency | Prefer a single database worker per origin. For multi-tab deployments, coordinate one writer using `BroadcastChannel`/Web Locks and use a compatible SQLite OPFS VFS. The standard `opfs` VFS requires COOP/COEP headers for `SharedArrayBuffer`; `opfs-sahpool` is a useful single-connection fallback when those headers or multi-tab behavior are unavailable.[3] |
| JSON-RPC-LD | Use `fetch` from a network service with a narrow `postRpc(method, params)` function. Pass only validated `SyncIntent` objects from the database worker to that service. Pin the JSON-LD context in the application bundle; do not dynamically load it. |
| Sync loop | Use a foreground controller triggered by startup, `online`, manual refresh, and visibility restoration. The worker serializes all database writes. A service worker MAY cache static application assets, but it SHOULD NOT hold credentials or become an unsupervised sync authority. |
| Private isolation | Keep private SQL access in a module that cannot call `fetch`. The network interface accepts a `SyncIntentPushRequest` only. Avoid logging worker messages or request objects wholesale. A browser’s same-origin script execution model makes a strict CSP, dependency control, and trusted HTML rendering essential; local ledger separation is a protocol guarantee, not a defense against arbitrary same-origin script compromise. |
| Packaging | Package as an ESM/Vite or equivalent PWA. Bundle Wasm, Worker, and pinned context assets with content hashes. Serve over HTTPS. Emit COOP/COEP only if the selected VFS needs them, and test storage quota/incognito fallbacks. |

The SQLite Wasm documentation states that OPFS is browser-side persistent storage usable for databases and that relevant OPFS SQLite support runs in worker contexts.[3] Browser clients should provide a clear degraded mode when OPFS is unavailable or ephemeral, rather than quietly treating transient storage as durable local-first state. The File System API documentation also warns that private storage behavior can vary in privacy modes.[3] [4]

### 9.3 Java client

| Concern | Implementation recommendation |
|---|---|
| Local SQLite | Use `org.xerial:sqlite-jdbc` through JDBC and an application-data SQLite file. The driver packages libraries for major operating systems in a JAR and provides standard JDBC access to SQLite files.[6] Set a busy timeout, enable foreign keys, and keep a single write executor. |
| JSON-RPC-LD | Use `java.net.http.HttpClient` plus Jackson or JSON-P for strict record construction and parsing. Model `CanonicalRecord`, `SyncIntent`, `PrivateLocalRecord`, and `PublicationPolicy` as distinct sealed interfaces/records. Never use an untyped `Map<String,Object>` at the network boundary. |
| Sync loop | Run a `ScheduledExecutorService` with a mutex keyed by StoreFile. Perform pull page transactions with `Connection#setAutoCommit(false)` and commit the cursor with records. Persist outbound intent state before transmitting. |
| Private isolation | Place `PrivateLocalRepository` in a package without dependency access to the RPC module. Restrict the push method signature to `List<SyncIntent>`. Use a test `HttpClient` adapter that records bodies and rejects a private sentinel. |
| Packaging | Use Maven or Gradle, produce a versioned JAR, then use `jlink`/`jpackage` where a native installer is needed. Validate native driver behavior on supported CPU/OS combinations in CI. |

The xerial driver documents the `jdbc:sqlite:` connection path and its bundled native library behavior, making it a practical default for a Java desktop client.[6] The client remains portable because JDBC implementation is a local concern; the JSON-RPC-LD wire records are unchanged.

### 9.4 Rust client

| Concern | Implementation recommendation |
|---|---|
| Local SQLite | Use `rusqlite` with the `bundled` feature when a system SQLite dependency is undesirable. `rusqlite` exposes SQLite connections, transactions, parameter binding, and typed row extraction in an ergonomic Rust API.[7] Keep the connection on a dedicated database thread or serialize it behind a mutex. |
| JSON-RPC-LD | Use `reqwest`, `serde`, and `serde_json`, with `#[serde(deny_unknown_fields)]` for protocol control records where compatibility permits. Use newtypes for `StoreId`, `RecordId`, `OperationId`, and `PolicyEpoch`; define `PrivateLocalRecord` separately from `SyncIntent`. |
| Sync loop | Use `tokio` for HTTP/backoff but execute SQLite work in `spawn_blocking` or a dedicated worker. A local transaction persists each cursor/page and each queue-state transition. Respect `Retry-After` and retain original operation IDs. |
| Private isolation | Make the RPC crate depend only on a `SyncIntentSource` trait that yields approved intents; do not link it to the private repository crate. Add compile-time visibility limits and an outbound body sentinel test. |
| Packaging | Publish a Cargo workspace with separate crates for `model`, `store`, `sync`, and optional UI. Ship binaries with `cargo build --release`, platform signing, and OS credential-store integration through a small adapter. |

The `rusqlite` documentation identifies it as a SQLite wrapper and exposes first-class `Connection`, `Transaction`, `Statement`, parameter, and error types, which are enough for a durable native local-store implementation.[7]

## 10. Cross-language conformance suite

The conformance suite proves **N language clients × one invariant Rails API**, not N server rewrites. It consists of a stable Rails fixture environment, protocol fixtures, and the same behavioral test catalog invoked by each client adapter.

### 10.1 Test-kit layout

```text
conformance/
  fixtures/
    context-v1.jsonld
    schema-task-v3.json
    policy-epoch-18.json
    canonical-snapshot.json
    canonical-change-feed.json
  contract/
    rpc-examples.json
    error-examples.json
    required-test-cases.md
  rails-fixture-api/
    seed-and-reset instructions only
  adapters/
    python/
    javascript-browser/
    java/
    rust/
```

The Rails fixture API is the same deployment for every run. It provides a seeded StoreFile, an allowed field such as `/tool:title`, a forbidden field such as `/tool:ownerRole`, a device enrollment fixture, controlled version conflicts, an expired cursor fixture, and request capture that stores only redacted test metadata. The test kit MUST not accept a client-specific server implementation.

### 10.2 Required behavioral tests

| ID | Scenario | Required assertion |
|---|---|---|
| C-01 | Negotiate | Client pins returned context, schema hash, policy epoch, and limits; unsupported schema prevents push. |
| C-02 | Initial canonical pull | Client stores every canonical record/tombstone and commits cursor atomically. A restart resumes from stored state. |
| C-03 | Incremental canonical pull | A server change after the snapshot is observed exactly once logically; duplicate delivery does not lower local version or corrupt state. |
| C-04 | Allowed sync-intent push | Client publishes exactly one allow-listed patch; server accepts it, assigns a higher canonical version/provenance, and client stores the returned record. |
| C-05 | Idempotent retry | Drop the first response after server processing; retry same intent; server returns `duplicate` without a second canonical mutation. |
| C-06 | Server allow-list enforcement | A deliberately malicious client bypasses its local guard and submits a forbidden path. Server rejects it and canonical data remains unchanged. |
| C-07 | Local policy mirror | A well-behaved client refuses to generate or enqueue that same forbidden patch before network transmission. |
| C-08 | Stale conflict | Advance the canonical record from another device; push an old-base intent; server returns `stale`, canonical wins locally, and no silent retry is made. |
| C-09 | Private-local isolation | Insert a unique sentinel into `private_local`. Assert it is absent from every SyncIntent JSON, HTTP body, request log, analytics event, canonical record, error report, and server fixture database. |
| C-10 | Cursor expiration | Server expires cursor; client preserves sync-intent/private-local rows, rebuilds only canonical cache, and completes a fresh snapshot. |
| C-11 | Context rejection | Client rejects a response using an unpinned context before applying it; no local cursor advances. |
| C-12 | Queue durability | Enqueue an intent, terminate client before sending, restart, and verify the original operation ID is pushed exactly once logically. |

C-09 deserves independent negative testing. It must include both normal behavior and an intentionally hostile UI value where the private sentinel resembles a permitted public value. The only passing result is that publication contains the explicitly selected permitted field and never the sentinel unless the user independently typed that same value into an allowed public field.

### 10.3 Language matrix and execution gates

| Client adapter | Runtime | Local SQLite target | Mandatory execution mode |
|---|---|---|---|
| Python | CPython | native SQLite file | Headless API/CLI test plus offline-restart test. |
| JavaScript | Chromium-family browser in CI | SQLite Wasm + OPFS | Real browser test, including Worker, storage persistence, and at least one OPFS contention/degraded-mode case. |
| Java | LTS JVM | native SQLite file through JDBC | Headless desktop/service test plus packaged artifact smoke test. |
| Rust | supported native targets | native SQLite file through `rusqlite` | Headless binary test plus cross-platform database-path test. |

A client is conformant only when all required cases pass against the same Rails fixture API and its serialized wire traces match the contract’s required shapes. The test harness should validate that each domain record has `@context` and `@id`, each push carries its current policy epoch, and no request includes a private sentinel.

## 11. Recommended first non-Ruby reference application

**Choose Python as the first non-Ruby reference client.** It delivers the smallest credible local-first proof with the standard `sqlite3` module, a straightforward CLI or compact desktop surface, easy fault injection, and no browser storage or native-driver packaging complexity. This choice does not deprioritize JavaScript; it intentionally proves the language-neutral channel and ledger boundary before adding OPFS worker and browser concurrency variables.

The smallest milestone is a single StoreFile and a single permitted field. It is complete when the Python application can initialize local tables, enroll/store a device credential, negotiate schema and policy, pull one canonical task into local SQLite, change an allowed title by creating one SyncIntent, push it idempotently, and persist a private working note that is demonstrably absent from the request body and server state.

| Milestone deliverable | Acceptance condition |
|---|---|
| `sync init` | Creates `canonical_record`, `sync_intent`, `private_local`, `sync_state`, and `intent_outcome`; no server schema is created. |
| `sync pull` | Negotiates then materializes canonical test task and cursor locally. |
| `task set-title` | Uses PublicationGuard to enqueue a `/tool:title` intent at current base version. |
| `task set-private-note` | Writes a PrivateLocal record only; no queued intent count changes. |
| `sync push` | Uses the same operation ID on retry and receives server canonical version/provenance. |
| Conformance run | Passes C-01 through C-12 against the Rails fixture API, especially C-06 and C-09. |

After this milestone, implement the JavaScript browser reference next. It exercises the same fixtures and wire traces but validates the distinctive OPFS-SQLite worker architecture. Java and Rust can then reuse the protocol fixtures without any Rails API divergence.

## 12. Risks and mitigations

| Risk | Failure mode | Mitigation and acceptance evidence |
|---|---|---|
| Policy drift | A cached client policy permits a field that server policy no longer allows. | Epoch and expiry on every push; server rejects stale policy; client negotiates and revalidates queued intents. C-06 and C-07 prove both sides. |
| Private-data leakage | Generic serialization, telemetry, diagnostics, or a broad SQL query sends `private_local` data. | Separate repository/type/module; narrow network signatures; redacted logging; sentinel capture test C-09; code review rule banning `SELECT *` across ledgers. |
| Lost or duplicate writes | Response loss causes client to repeat a canonical mutation. | Durable operation IDs, idempotency result store, replay tests C-05 and C-12. |
| Offline conflict | Another device changes a record while a client is offline. | Strict base-version comparison; server canonical wins; visible rebase workflow; C-08. |
| Browser OPFS contention | Multiple tabs hold conflicting locks or private mode provides transient storage. | Single-worker coordinator, capability detection, short transactions, explicit degraded mode, and browser conformance coverage. SQLite’s OPFS guidance notes worker requirements and concurrency trade-offs.[3] |
| Context substitution | A malicious or accidental context changes the interpretation of record terms. | Pin immutable contexts, reject unknown contexts, no runtime remote context fetch; C-11. |
| Device-token compromise | Credential stolen from logs or insecure client storage. | TLS, short-lived/revocable per-device credentials, OS credential vault or HttpOnly cookie, no token in ledgers/logs, rotation and revocation test. |
| Schema evolution | A new server schema is misread by an older client. | Explicit negotiate range and schema hash; pulls only when safely validated; pushes fail closed on incompatibility. |
| Unbounded retry load | Persistent auth, conflict, or policy failures cause request storms. | Categorized errors, bounded exponential backoff/jitter, stop-and-notify conditions, honor `Retry-After`. |
| False local confirmation | UI displays a pending local change as canonical. | Distinct canonical/pending/rejected states in presentation model; accepted response or later pull is the only canonical confirmation. |

## 13. Implementation sequence

| Order | Deliverable | Boundary preserved |
|---:|---|---|
| 1 | Publish immutable v1 JSON-LD context, schema descriptor format, and protocol examples. | No application language or server rewrite decision is embedded in the contract. |
| 2 | Add the three JSON-RPC methods and device enrollment path to the existing Rails API, backed by its existing canonical SQLite schema and authorization layer. | Rails remains the only server. |
| 3 | Implement server-side policy validation, versioning, idempotency outcome storage, and cursor fixture support. | Server remains authoritative for every publish decision. |
| 4 | Build Python reference milestone and conformance test kit. | First client proves only the channel and local ledgers. |
| 5 | Build JavaScript OPFS-SQLite client against unchanged fixtures. | Browser differs only in local storage/runtime. |
| 6 | Build Java and Rust clients against unchanged fixtures. | Native language differences remain client-local. |
| 7 | Gate releases on the N × 1 conformance matrix and private-local sentinel test. | No client can create a language-specific server fork. |

## 14. Final acceptance criteria

The plan is implemented correctly only if all of the following are true: there is one Rails API and one canonical schema/migration authority; every client maintains its own local SQLite with all three logical ledgers; every protocol record sent or received has `@context` and `@id`; canonical data is acquired through cursored pull; only exact allow-listed SyncIntent patches are pushed; private-local values cannot be serialized into an outbound request; stale writes do not override server canonical data; operation IDs make retries idempotent; and Python, JavaScript, Java, and Rust all pass the same conformance suite against the same Rails fixture API.

## Appendix S -- SHACL shape files (normative, added in v0.2)

Every ledger record and wire payload is a JSON-LD graph; the shape files under
`shapes/cyborg-channel/` are the normative, machine-checkable form of this specification. They are
validated by the **server on ingest** (authoritative), by a **client before push** (fail fast), and
by the **conformance suite** (section 10) against the shared fixtures -- so all four language clients
and the Rails server enforce ONE contract, not N reimplementations.

| Shape file | Validates | Sections |
|---|---|---|
| `envelope.shacl.ttl` | common envelope (@id is an IRI, @type, StoreFile binding) + provenance | 3.3 |
| `canonical-record.shacl.ttl` | canonical records + tombstones | 4.1 |
| `sync-intent.shacl.ttl` | **sh:closed** sync-intent + patch -- the allow-list/privacy boundary | 4.2, 6 |
| `private-local.shacl.ttl` | private-local records + the never-transmit rule | 4.3 |
| `allowlist.template.shacl.ttl` | per-StoreFile allow-list (generated; client mirrors read-only) | 6 |

**Why closed shapes matter.** `sh:closed true` on cyb:SyncIntentShape and cyb:PatchShape means a
SyncIntent may carry only the declared properties. A server-authoritative field (sf:version,
sf:state, sf:provenance, sf:updatedAt) or any private/local field appearing in an intent is a SHACL
violation -- the push is rejected before it can touch canonical state. That is the invariant
"private_local never leaves; the app never claims canonical authority", enforced by a validator.

Vocabulary (sf:) follows section 3.2; `sync.example.org` is illustrative -- each deployment
substitutes its own immutable namespace and pinned JSON-LD context, and generates the per-StoreFile
allow-list shape from its authoritative allow-list.

## References

[1]: https://www.jsonrpc.org/specification "JSON-RPC 2.0 Specification"
[2]: https://www.w3.org/TR/json-ld11/ "W3C JSON-LD 1.1 Recommendation"
[3]: https://sqlite.org/wasm/doc/trunk/persistence.md "SQLite Wasm: Persistent Storage Options and OPFS VFS"
[4]: https://developer.mozilla.org/en-US/docs/Web/API/File_System_API "MDN File System API and Origin Private File System"
[5]: https://docs.python.org/3/library/sqlite3.html "Python sqlite3 — DB-API 2.0 interface for SQLite databases"
[6]: https://github.com/xerial/sqlite-jdbc "xerial SQLite JDBC Driver"
[7]: https://docs.rs/rusqlite/ "rusqlite crate documentation"
