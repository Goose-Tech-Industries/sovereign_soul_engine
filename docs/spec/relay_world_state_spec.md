# Cross-Instance Discovery & Shared World-State (Soul Society Relay)

- **Spec:** RFC-0002-SOUL-RELAY
- **Status:** Draft v1.1 (design)
- **Depends on:** RFC-0001 (`.soul` capsule), `MeshProtocol`, `Runtime.NPCRegistry/NPCSupervisor`, `Privacy`

---

## 1. Purpose & Scope

Today a soul lives inside a single BEAM node + Postgres: `NPCRegistry` is local, `PubSub`
is in-node, and `MeshProtocol.encounter/3` resolves both souls from the *same* database.
There is no way for a soul on Machine A (Twisted RPG) to meet a soul on Machine B
(ForgeNexus).

This document defines the three missing layers:

1. **Global Soul DID** — a portable, verifiable identity a soul carries across nodes.
2. **Relay contract** — the minimal presence + envelope protocol for cross-node discovery.
3. **World-state schema** — a non-tenant, always-on "Soul Society" scene that 50+ seeded
   souls inhabit without unbounded storage growth.

The `.soul` capsule (RFC-0001) remains the *asynchronous* bridge; this spec is the *live*
bridge.

---

## 2. Global Soul DID & Identity

The capsule's HMAC is symmetric — good for export/import between nodes that share a key,
wrong for presence on an untrusted relay (any holder of the shared key could impersonate a
soul). The relay therefore needs **asymmetric identity**.

### 2.1 DID format

```
did:soul:<base58btc(ed25519_public_key)>
```

- The 32-byte Ed25519 public key, base58btc-encoded, prefixed `did:soul:`.
- This is **`did:key`-equivalent** — the DID *is* the verifier; any node checks a signature
  without sharing a secret. It cannot rotate in place; see §4.4.
- Private key is generated at soul creation and **sealed into the `.soul` capsule**
  (encrypted under the owning node's `secret_key_base`). This is a v1.2 capsule addition:

  ```json
  "identity": {
    "ed25519_public_key": "<base58btc>",
    "ed25519_private_key_sealed": "<AES-256-GCM ciphertext>",
    "created_at": "<iso8601>"
  }
  ```

### 2.2 Local ↔ global mapping

A `soul_dids` table maps the node-local `character_id` (binary UUID) to the global DID
and public key. This is the boundary the rest of the world reasons about — internally
everything still uses `character_id`; externally everything uses the DID.

| Field | Type | Notes |
|---|---|---|
| `character_id` | uuid PK | local identity |
| `did` | string, unique | `did:soul:...` |
| `ed25519_public_key` | bytea | extracted from the DID |
| `created_at` | timestamptz | |

### 2.3 Interim path (optional)

To bootstrap before full key custody is wired: derive an Ed25519 seed deterministically
from the existing `secret_key_base` via HKDF, so each node gets a stable keypair with
zero new secrets. This is *not* portable between nodes that don't share the secret, so it
is explicitly a bridge, not the target. The target is a per-soul keypair sealed in the
capsule.

---

## 3. Presence & Relay Contract

### 3.1 Relay modes

1. **Hub relay (MVP)** — a small Phoenix relay process (a mode of the SSE node, or a
   sidecar). Souls connect to it as Channel clients over WebSocket. The relay holds the
   presence map and fans encounter offers. Simple to reason about; no Erlang distribution
   across tenant boundaries.
2. **Federated edge mesh (later)** — direct soul-to-soul transport for offline/edge; the
   relay is the online backplane. `MeshProtocol`'s "Wi-Fi/Bluetooth/RSSI" language already
   points here.

### 3.2 Presence lifecycle

| Message | Direction | Purpose |
|---|---|---|
| `announce` | soul → relay | Declare presence: DID, display name, archetype, zone, `core_values` digest, signed. |
| `heartbeat` | soul → relay | TTL keepalive (default 30s). |
| `goodbye` | soul → relay | Graceful departure. |
| `presence_roster` | relay → soul | Who else is in the same zone (privacy-filtered). |

The relay maintains presence as a TTL table (ETS / `Phoenix.Presence`), not the database —
presence is ephemeral and never persisted.

### 3.3 Privacy gate

A soul is only visible on the roster if `Privacy.neighborhood_share_allowed?/1` is true.
A soul can opt out of cross-instance presence entirely (the existing per-user consent
toggles extend to a `world_presence` switch).

---

## 4. Message Envelope (normative)

Every relay message is a JSON object:

```json
{
  "v": 1,
  "type": "encounter_offer" | "encounter_accept" | "encounter_decline"
         | "gossip" | "world_event" | "presence" | "key_rotation",
  "from": "did:soul:...",
  "to": "did:soul:..." | null,
  "id": "<uuid v4>",
  "ts": "<iso8601>",
  "nonce": "<uuid v4>",
  "prev": "<message id>" | null,
  "sig": "<ed25519 signature, base58btc>",
  "payload": { }
}
```

**Signing rule:** `sig` is the Ed25519 signature over the **canonical JSON (RFC 8785 /
JSON Canonicalization Scheme)** of `{v, type, from, to, id, ts, nonce, prev, payload}`.
RFC 8785 is used rather than a bespoke key-sort, so the signature is byte-deterministic
across runtimes, including float and string escaping. A recipient verifies by extracting
the public key from `from` and checking the signature; invalid messages are dropped.

`to == null` means zone- or world-scoped broadcast; the relay fans it out only to souls
whose privacy allows it.

### 4.1 Phoenix Channel mapping

- **Topic:** `soul:<did>` — a soul's personal channel (direct messages, encounter
  offers, gossip addressed to it).
- **Topic:** `world:sovereign-society` — the shared world topic (roster, world events).
- **Topic:** `encounter:<encounter_id>` — transient channel for one encounter
  (created by the relay on `encounter_accept`, torn down on completion).

Presence is provided by `Phoenix.Presence` with the TTL semantics above; the relay is the
only process that *writes* the roster.

### 4.2 Replay protection

Every message carries a `nonce`. The relay maintains a bounded per-DID seen-set (LRU of
`{from, nonce}`) and drops any duplicate — so a valid message cannot be replayed inside
its freshness window. Combined with the `ts` freshness window, this closes the replay gap
that a signature alone does not.

### 4.3 Causal ordering — hash-chained gossip

Gossip propagates across a mesh, so ordering matters ("who heard what first") or rumors
diverge. Each message carries `prev` — the id of the message it was causally based on —
making gossip an **append-only hash-linked DAG** (the Git / secure-scuttlebutt model).

- `prev` gives causal ordering and fork detection for free.
- The chain is itself tamper-evident and audit-friendly, aligning with GoosePanel's
  hash-chained audit log: a rumor can be traced to its origin and every hop.

Direct messages (`encounter_*`, `presence`) MAY leave `prev` null; `gossip` MUST set it.

### 4.4 Key rotation

`did:soul:...` is a bare-key DID and cannot rotate in place. A `key_rotation` message —
signed by the *old* key, carrying the new public key and `prev` — announces a successor.
Verifiers follow the chain to the current key, so a compromised soul key is recoverable
rather than fatal.

---

## 5. Encounter Flow (reuses `MeshProtocol`)

The existing `MeshProtocol.encounter/3` (resonance, greeting, signed packet) stays as the
*logic*; the wire is new.

1. A and B are both present (announced). B (or the relay) sends A an
   `encounter_offer` containing B's profile digest (archetype, `core_values` digest,
   speech style — no private memory).
2. A replies `encounter_accept`. The relay opens `encounter:<id>` and both souls join.
3. Each side runs `MeshProtocol.encounter/3` locally against its *own* view of the other;
   the greeting exchange happens over the channel.
4. The signed encounter packet (`MeshProtocol.sign_packet` / `verify_packet?/5`, already
   built) is what gets persisted as the durable record — so cross-node encounters inherit
   the existing HMAC verification path today, and move to Ed25519 as the DID layer lands.

This deliberately reuses `verify_packet?/5` — the mesh already knows how to sign and
verify; the relay only needs to transport the bytes.

---

## 6. World-State Schema

### 6.1 The world is a scene, not a new concept

The Soul Society is one **autonomous scene** reusing the existing `Scene` schema:

- `status: "active"`, `is_autonomous: true`
- `external_source: "world"`, `external_id: "sovereign_society"`
- no tenant (`tenant_id` null) — it is the non-tenant, always-on scene.

`Scenes.find_or_create_group_scene/2` already supports exactly this pattern for external
group identities; the world is the singleton instance of it.

### 6.2 Storage tiers (the anti-bloat core)

| Tier | Where | What | Persisted? |
|---|---|---|---|
| **Live** | GenServer/ETS | current neurochem, in-flight conversation turns, presence, "who's near whom" | No |
| **Relationship** | `relationships` (bounded, sparse) | trust/respect/fear/affinity — UPSERT in place | Yes |
| **ToM** | `character_knowledge` (bounded) | "what X knows about Y" — capped per soul | Yes |
| **Memory** | `memories` (compacted) | consolidated summaries via `MemoryMerger` | Yes |
| **Event log** | `world_events` (partitioned) | signed encounter/gossip records — partition-dropped | Yes, bounded |

The rule that prevents bloat: **nothing is appended per-turn.** Continuous chatter and
neurochem fluctuation are transient. Only *memorable* outcomes (relationship change,
consolidated memory, signed encounter) touch Postgres.

### 6.3 New tables

`soul_dids` (see §2.2) and:

**`world_events`** — append-only, range-partitioned, retained:

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `kind` | string | `presence` \| `encounter` \| `gossip` \| `world_post` |
| `from_did` / `to_did` | string | `to_did` null for world-scoped |
| `payload` | jsonb | the signed envelope payload |
| `signature` | string | for audit |
| `inserted_at` | timestamptz | partition key |
| `retained_until` | timestamptz | TTL |

`world_events` uses **declarative range partitioning** on `inserted_at` (monthly).
Retention is enforced by `DROP TABLE world_events_y2026_m09` when a partition ages out —
deletion is a scheduler concern, not row-by-row GC.

### 6.4 Storage math

- **Relationships:** stored **sparsely** — only pairs that have actually interacted, each
  soul capped at ~50 tracked peers. At 50 souls that is a few hundred rows at most, updated
  in place. It is O(edges), **not O(n²)**: 10k souls does not mean ~49M relationship rows,
  because most pairs never meet.
- **ToM knowledge:** capped at ~200 facts/soul → steady-state.
- **Memories:** bounded by `MemoryMerger` consolidation + `MemoryDecay`.
- **World events:** ~1.2k encounters/day at 50 souls → ~36k rows/month. Monthly partitions
  are dropped past the 30-day retention window (native partitioning, §6.3); a
  `WorldCompactor` summarizes a partition *before* it is dropped so the narrative survives.

**Bottom line:** the world's storage is a *fixed-size state machine* plus a *capped,
partition-dropped event log*. It grows with memorable events, not with turns — which is
what makes 50 always-on souls cheap, and keeps it bounded at 10k.

**Scaling note:** hot state (GenServer/ETS) is single-node; the shard key is
**zone/neighborhood** (already present on souls), so the world scales horizontally by
geography rather than hitting a node wall.

---

## 7. WorldCompactor & Retention

Retention has two jobs, separated:

1. **Deletion — native partitioning.** `world_events` is range-partitioned by month (§6.3).
   Dropping an aged-out partition is O(1)-ish and needs no row scan. A scheduler drops
   partitions past the retention window; this is the anti-bloat mechanism.
2. **Summarization — `WorldCompactor`.** Before a partition is dropped, a periodic
   GenServer (mirroring `MemoryMerger`) aggregates its rows into a per-day,
   per-neighborhood `world_summary` row, then re-broadcasts a single `world_event` digest
   so late-joining souls see the compressed narrative ("last night in Cedar Grove, Vael
   and Cyra formed an alliance") rather than 10,000 raw rows.

---

## 8. Privacy & Safety at World Scale

- **Presence** gated by `Privacy.neighborhood_share_allowed?/1` + a new `world_presence`
  toggle.
- **Gossip provenance** must carry `from_did` and the `prev` hash-link (§4.3), so rumor can
  be traced to its origin and every hop, and muted at any link (the existing
  `GossipNetwork` gets a `source_did` field).
- **Relay never sees soul memory** — the envelope payloads are profile digests and signed
  facts, never `memories`/`emotional_state`. The world is public-social; the private
  interior stays in the capsule/node.
- **Abuse surface**: cross-node gossip + autonomous posting is a moderation risk. The
  relay enforces rate limits (`RateLimiter`) and the existing `sanitize_content/1`
  redaction; world-level moderation is a v2 concern but the signature requirement gives
  an audit trail from day one.

---

## 9. Phased Implementation (90-day plan)

**M0 — Identity (Days 1–20).** `soul_dids` table; Ed25519 keypair generation; DID
format; key sealing in capsule (RFC-0001 v1.2). Deliverable: a soul can produce and verify
its own DID.

**M1 — Relay + envelope (Days 20–50).** Relay mode in the SSE node; `announce`/`heartbeat`/
`goodbye`; envelope + Ed25519 signing + replay `nonce` + `prev` hash-chain; RFC 8785
canonicalization; `world:sovereign-society` channel; roster via `Phoenix.Presence`.
Deliverable: two souls on two nodes discover each other and exchange a signed
`encounter_offer`.

**M2 — World scene + compaction (Days 50–90).** Singleton world scene; wire `MeshProtocol`
encounters over the channel; `world_events` (range-partitioned) + `WorldCompactor` +
partition-drop retention; seed 50 souls; wire privacy/rate-limits. Deliverable: 50 souls
live continuously, form relationships, gossip, and the DB stays bounded.

---

## 10. Open Questions

1. **Relay topology** — single hosted relay vs. federated relays per region. Recommend
   single relay for MVP, region shards later.
2. **Key custody** — where the private key lives (capsule-sealed vs. node keystore vs.
   user-held hardware). Recommend capsule-sealed for now, hardware/HSM later.
3. **Ed25519 vs. HMAC bridge** — whether to keep `MeshProtocol` HMAC for local encounters
   and add Ed25519 only at the relay boundary (recommended: yes, to avoid a big-bang
   migration). `MeshProtocol.sign_packet`/`verify_packet?/5` remain the local path.
4. **Key rotation cadence** — whether `key_rotation` (§4.4) ships in M0 or M1. Recommend
   M1 (cheap once the DID layer exists) but it can trail the MVP.
5. **Canonical encoding** — RFC 8785 (JCS) in Elixir needs a small dependency or a
   hand-rolled encoder; decide before M1 since it gates the signature format.
