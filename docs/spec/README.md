# Sovereign Soul Engine — Open Specifications

The `.soul` capsule and the Soul Society relay are intended to be **open,
implementable standards**, not a walled garden. These RFC-style documents are the
canonical specs; the Elixir implementation is one reference implementation.

| Spec | Status | What it defines |
|---|---|---|
| [`soul_capsule_spec.md`](soul_capsule_spec.md) | Draft v1.1 | The portable `.soul` capsule: identity, memory, relationship graph, HMAC integrity. |
| [`relay_world_state_spec.md`](relay_world_state_spec.md) | Draft v1.1 | DID identity, signed envelope, presence, and the shared world-state schema. |

## Publishing (the standard play)

To make these *the* standard rather than *our* docs:

1. **Cut a release** of each spec (tag them `RFC-0001-v1.1`, `RFC-0002-v1.1`) so
   third parties can reference a stable version.
2. **Ship a conformance suite + test vectors** (the `.soul` capsule already has a
   reference round-trip test; add a golden test-vector file a third-party
   implementation can run against).
3. **Reference implementation in two languages** — the Elixir engine is one; the
   `sdk/js/relay_client.js` is a second, independently written implementation
   that byte-matches the wire protocol (already proven over TCP).

Until (1) and (2) land, these are drafts. The honest flag is in each document's
conformance matrix: what's implemented vs. still `REQUIRED`.
