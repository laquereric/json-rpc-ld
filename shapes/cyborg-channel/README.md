# SHACL shape files -- Cyborg App JSON-RPC-LD channel (v0.2)

Normative validation layer for
[`cyborg_app_jsonrpcld_channel_plan_v0.2.md`](../../cyborg_app_jsonrpcld_channel_plan_v0.2.md).
Every ledger record and every wire payload is a JSON-LD graph; these SHACL shapes are the
machine-checkable form of the plan's constraints. The server validates on ingest (authoritative);
a client SHOULD validate before push; the conformance suite validates fixtures against them.

| Shape file | Validates | Plan section |
|---|---|---|
| `envelope.shacl.ttl` | common envelope (IRI @id, @type, StoreFile binding) + provenance | 3.3 |
| `canonical-record.shacl.ttl` | canonical ledger records + tombstones | 4.1 |
| `sync-intent.shacl.ttl` | **closed** sync-intent + patch (the privacy/authority boundary) | 4.2, 6 |
| `private-local.shacl.ttl` | private-local records + the never-transmit rule | 4.3 |
| `allowlist.template.shacl.ttl` | per-StoreFile allow-list (generated; client mirrors read-only) | 6 |

Why SHACL, not ad-hoc checks: `sh:closed true` on the SyncIntent/Patch shapes means the
allow-list and the "no server-authoritative or private field crosses" invariant are enforced
by a standard validator, identically in every language client and on the server -- one contract,
not N reimplementations. Vocabulary (`sf:`) follows plan section 3.2; `sync.example.org` is
illustrative -- each deployment substitutes its own immutable namespace + pinned JSON-LD context.
