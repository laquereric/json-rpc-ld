# JSON-RPC-LD ontology (Data perspective)

`json-rpc-ld-core.ttl` is the **core OWL 2 vocabulary** for JSON-RPC-LD: `Envelope`,
`Operation`, `Outcome` (`Result` / `Error`), and the identity/idempotency datatype
properties (`operationId`, `jsonRpcVersion`, `methodName`, `reason`, `because`).

- **Ontology IRI:** `https://w3id.org/json-rpc-ld/ontology/core/1.0.0`
- **Term namespace:** `https://w3id.org/json-rpc-ld/ns#` (`jrl:`)

It is the **root of the import chain**: it imports nothing, and a profile that
specializes JSON-RPC-LD imports it. OWL states *meaning*; a profile states closed
operational *validity* in SHACL, alongside its own terms. Open in
[Protégé](https://protege.stanford.edu/) via File → Open.

This is the **Data** view of the vocabulary — the ontology as a reasoner consumes
it. Profiles build on these terms; nothing defined here depends on a profile,
and this ontology is complete without one.
