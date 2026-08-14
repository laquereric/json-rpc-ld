# json-rpc-ld

**Specification repository** -- two layered specs and their validation shapes. No
implementation lives here; the reference implementation is the invariant Rails API.

- **JSON-RPC-LD** -- the larger, general protocol: a Linked Data extension of JSON-RPC
  2.0. File: `JSON-RPC-LD: A Linked Data Extension for JSON-RPC 2.0.md`.

- **Cyborg Channel** -- a domain **profile that conforms to** JSON-RPC-LD: the
  local-first, three-ledger (canonical / sync_intent / private_local) sync channel
  between a Cyborg App's local SQLite (OPFS-SQLite in the browser) and an invariant
  Rails API. File: `cyborg_app_jsonrpcld_channel_plan_v0.2.md`.

- **SHACL shapes** -- now hosted in the osi-level-8 repo (`shapes/cyborg-channel/` there: https://github.com/laquereric/osi-level-8); previously `shapes/cyborg-channel/` here: the normative, machine-checkable
  validation layer for Cyborg Channel records. The closed sync-intent/patch shapes make
  the allow-list + privacy invariant (private_local never leaves; no server-authoritative
  field crosses) validator-enforced.

The Cyborg Channel is one application of JSON-RPC-LD; JSON-RPC-LD is the general protocol
many profiles can conform to. A prior Rails-engine scaffold was removed -- it was not
consistent with either spec.
