# JSON-RPC-LD ontology (Data perspective)

`json-rpc-ld-core.ttl` is the **core OWL 2 vocabulary** for JSON-RPC-LD: `Envelope`,
`Operation`, `Outcome` (`Result` / `Error`), and the identity/idempotency datatype
properties (`operationId`, `jsonRpcVersion`, `methodName`, `reason`, `because`).

- **Ontology IRI:** `https://w3id.org/laquereric/json-rpc-ld/ontology/core/1.0.0`
- **Term namespace:** `https://w3id.org/laquereric/json-rpc-ld/ns#` (`jrl:`)

It is the root of the import chain: **CPCP base** imports this, and each **PS1-PX**
profile imports CPCP base. OWL states *meaning*; SHACL (in the profile repos) states
closed operational *validity*. Open in [Protégé](https://protege.stanford.edu/) via
File → Open.

This is the **Data** view of the one-model/three-views design (Human + AI = the OKF
bundle; Data = these ontologies + SHACL). See the CPCP standard for the coherence model.
