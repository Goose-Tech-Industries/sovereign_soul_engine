# Sovereign Soul Capsule Specification (`.soul`)

- **Spec:** RFC-0001-SOUL-CAPSULE
- **Status:** Draft v1.1
- **Engine reference:** `SovereignSoulEngine.Souls.SoulCapsule` (`lib/sovereign_soul_engine/souls/soul_capsule.ex`)
- **Format version:** `sovereign_soul_capsule/v1`

---

## 1. Purpose

The `.soul` capsule is a portable, cryptographically integrity-checked container that
bundles a companion's persistent identity, psychology, and memory so it can be exported
from one engine/node and reconstituted on another — without losing who the soul *is*.

A capsule is a single JSON document. The only hard requirement on the surrounding
runtime is that it can read JSON and verify an HMAC-SHA256 checksum.

### Terminology

The key words **MUST**, **MUST NOT**, **SHOULD**, and **MAY** in this document are to be
interpreted as described in RFC 2119.

### Conformance notation

- **`v1`** — implemented today in `soul_capsule.ex`, verified by `soul_capsule_test.exs`.
- **`REQUIRED`** — part of the standard but **not yet implemented** (see §8 Gaps). These are
  binding for the next format revision and SHOULD be treated as roadmap, not optional.

---

## 2. Envelope & Versioning

A capsule is the top-level JSON object:

| Field        | Type     | Requirement | Description |
|--------------|----------|-------------|-------------|
| `format`     | string   | REQUIRED    | `"sovereign_soul_capsule/v1"`. Parsers MUST reject any other value. |
| `engine`     | string   | REQUIRED    | Provenance identifier of the exporting engine, e.g. `"SovereignSoulEngine/2.0"`. Informational; MUST be preserved verbatim. |
| `exported_at`| string   | REQUIRED    | ISO-8601 UTC timestamp of export. |
| `checksum`   | string   | REQUIRED    | Lowercase hex HMAC-SHA256 of the canonical serialization of the `soul` object (see §6). |
| `soul`       | object   | REQUIRED    | The payload (see §3–§5). |

```json
{
  "format": "sovereign_soul_capsule/v1",
  "capsule_id": "9f8b0a2d-1c3e-4f5a-8b6d-7e9c0a1b2c3d",
  "engine": "SovereignSoulEngine/2.0",
  "exported_at": "2026-09-17T12:00:00Z",
  "checksum": "6f1d2c...",
  "soul": { "...": "..." }
}
```

### Capsule identity (implemented in v1.1)

A `capsule_id` (UUIDv4) field is emitted on export. It is a stable identifier for the
*capsule document itself* (not the soul inside), enabling dedupe, audit, and conflict
detection on import. Importers MUST tolerate its absence (older capsules) but SHOULD
preserve it verbatim when present.

---

## 3. Deterministic Identity & Somatic Baselines

The `soul` object's identity and body-state are captured under these keys. All keys are
optional in practice (an importer falls back to sensible defaults); a fully-populated
export includes all of them.

### `soul.character` (identity)

| Field         | Type   | Notes |
|---------------|--------|-------|
| `name`        | string | Display name. |
| `slug`        | string | Portable handle. MUST be unique within an engine namespace; importers MUST deconflict (see §7). |
| `kind`        | string | `"npc"` \| `"player"` \| … (engine-defined). |
| `status`      | string | `"active"` etc. |
| `description` | string | Free-form identity description. |

### `soul.soul_profile` (personality & baselines)

| Field                     | Type      | Notes |
|---------------------------|-----------|-------|
| `personality_traits`      | object    | Free-form trait map. **The `"archetype"` trait is the canonical archetype key.** |
| `attachment_style`        | string    | `"secure"` \| `"anxious"` \| `"avoidant"` \| `"disorganized"`. |
| `identity_summary`        | string    | One-line self-narrative. |
| `speech_style`            | string    | Voice/diction descriptor. |
| `humor_style`             | string    | Humor descriptor. |
| `emotional_susceptibility`| integer   | 0–100 contagion sensitivity. |

### `soul.emotional_state`

`stress`, `anger`, `fear`, `gratitude`, `confidence`, `sadness`, `curiosity`,
`attachment`, `shame`, `guilt` (each integer 0–100), plus `rumination_subject` (string)
and `rumination_intensity` (integer).

### `soul.somatic_state`

`fatigue`, `pain`, `hunger`, `illness_severity` (integer 0–100) and
`circadian_chronotype` (string, e.g. `"night_owl"`).

### Gaps against the ideal model (`REQUIRED`)

The following MUST be added to make the capsule a complete "deterministic identity":

1. **Neurochemistry baselines** — explicit `cortisol`/`oxytocin`/`dopamine`/`serotonin`
   baseline ranges. Today these are *computed* (defaults in `Neurochemistry`) and never
   persisted or exported.
2. **Intimacy ceiling** — the relationship archetype's attachment ceiling (e.g. Platonic
   Mentor `40`, Romantic Partner `100`). Today ceilings are derived by `privacy.ex` at
   runtime from the archetype, not stored.
3. **Safe-word trigger** — the per-soul persona-freeze trigger. Today safe-word is a
   global privacy setting, not part of the soul.

---

## 4. Memory & Theory-of-Mind Graph

### `soul.memories` (array of objects)

| Field                | Type      | Notes |
|----------------------|-----------|-------|
| `category`           | string    | `working` \| `episodic` \| `relationship` \| `core` \| `wound` \| `belief`. |
| `summary`            | string    | The memory text. |
| `details`            | object    | Free-form structured detail (e.g. `{"narrative": "..."}`). |
| `emotional_intensity`| integer   | 0–100. |
| `valence`            | number    | −1.0 … +1.0. |
| `importance`         | integer   | 0–100. |
| `tags`               | string[]  | Semantic tag cluster. |

### Gaps (`REQUIRED`)

1. **Consolidation lineage** — the `consolidated_into_id` link that records which
   memories were merged into a consolidated summary. Not exported today, so a
   re-imported soul loses the merge lineage.
2. **Theory-of-Mind knowledge** (`character_knowledge`: known facts, certainty,
   assumption flags) is **not exported at all**. This is a core part of "who the soul
   knows," and its absence makes the capsule incomplete for true portability.

---

## 5. Inter-Soul Relationship Graph (implemented in v1.1)

A `soul.relationships` array is exported, with targets resolved by **slug** (never internal
DB UUID, which is node-local and non-portable). Each entry carries:

`target_slug`, `relationship_type`, `affinity`, `trust`, `respect`, `fear`, `anger`,
`gratitude`, `debt`, `wound`, and `last_interaction_at` (ISO-8601).

On import, each entry is reconciled:

- If `target_slug` resolves to a local character, a directional `Relationship` is created
  (source = imported soul, target = that character).
- If it does not resolve, the entry is stored in the imported character's
  `metadata["unresolved_relationships"]` pending map so it can reconnect when that soul
  later enters the world.

Still REQUIRED for the network: `soul.encounters` (signed inter-soul encounter logs, per
the mesh protocol) and `soul.gossip_tags` (shared rumor provenance).

---

## 6. Cryptographic Integrity & Verification

### Algorithm (normative)

```
checksum = lowercase_hex( HMAC-SHA256( key = signing_key, message = canonicalize(payload) ) )
```

where `payload` is the `soul` object, `canonicalize` is recursive key-sorted JSON
serialization, and `signing_key` is derived (see below).

Importers MUST:

1. Require the top-level `format`, `soul`, and `checksum` keys, else fail with
   `:malformed_capsule_structure`.
2. Verify `format == "sovereign_soul_capsule/v1"`, else fail with
   `:unsupported_capsule_format`.
3. Recompute the checksum over the `soul` object using the same key and canonicalization,
   and compare in constant time, else fail with `:checksum_mismatch_corrupted_capsule`.

### Signing key derivation (resolved in v1.1)

The key is derived in priority order:

1. `opts[:secret_key]` (caller-supplied, non-empty),
2. the engine's `SovereignSoulEngineWeb.Endpoint` `:secret_key_base`,
3. the `SECRET_KEY_BASE` environment variable.

This replaces the previous hardcoded compile-time salt, so a capsule's checksum can only
be verified by a node that holds the same secret — providing **authenticity**, not just
accidental-corruption detection. A shared static fallback is used only when none of the
above are configured, and MUST NOT be relied upon for any real trust boundary.

### Canonicalization (resolved in v1.1)

The checksum input is recursively key-sorted before encoding, so byte-identical
verification is independent of map insertion order across engines. Full RFC 8785
conformance (including canonical float and string escaping) remains a `SHOULD`; the
current implementation canonicalizes key order but leaves numeric formatting to the
encoder.

---

## 7. Engine Portability & Conflict Resolution

### Import contract

`import_capsule/2` accepts a JSON string or a parsed map, with options:

| Option      | Default | Behavior |
|-------------|---------|----------|
| `overwrite` | `false` | When `false`, a colliding `slug` is renamed to `"{slug}_{n}"` and a **new** character is created. When `true`, the existing character is updated in place. |

The import runs in a single database transaction (`Ecto.Multi`) over the character,
profile, emotional state, somatic state, memories, beliefs, desires, goals, shadows,
fears, and relationships. If any step fails, the whole import rolls back.

### Reconstitution rules (normative)

- **Character**: create-or-update by `slug`; missing fields fall back to defaults
  (`name` → `"Imported Companion"`, `kind` → `"npc"`, `status` → `"active"`).
- **Profile / emotional / somatic**: create-if-absent, else merge provided keys over
  existing.
- **Memories**: appended; `occurred_at` is stamped at import time; missing `category`
  defaults to `episodic`, missing `tags` to `["capsule_restored"]`.
- **Beliefs / desires / goals / fears**: appended; missing required fields fall back to
  valid defaults.
- **Shadows**: restored under a synthetic "Capsule Import — {name}" scene (a `SoulShadow`
  is scene-scoped, and scenes are node-local and non-portable).
- **Relationships**: resolved by `target_slug`; unresolved entries are held in
  `metadata["unresolved_relationships"]`.

### Round-trip fidelity (resolved in v1.1)

The v1.0 asymmetry — where the exporter wrote `beliefs`, `desires`, `goals`, `shadows`,
and `fears` but the importer discarded them — is fixed. Every field the exporter writes
is now restored on import.

---

## 8. Conformance Matrix & Gaps

| Area                          | Status    | Notes |
|-------------------------------|-----------|-------|
| Envelope + versioning         | `v1`      | ✓ implemented |
| `capsule_id` UUID             | `v1`      | ✓ emitted on export |
| Identity + emotional/somatic  | `v1`      | ✓ implemented |
| Neurochemistry baselines      | `REQUIRED`| computed, not exported |
| Intimacy ceilings             | `REQUIRED`| derived at runtime, not stored |
| Safe-word trigger             | `REQUIRED`| global, not per-soul |
| Memory graph                  | `v1`      | ✓ (no consolidation lineage) |
| `consolidated_into_id` lineage| `REQUIRED`| not exported |
| Theory-of-Mind knowledge      | `REQUIRED`| not exported |
| Relationship graph            | `v1`      | ✓ exported/imported by slug |
| Encounter logs / gossip tags  | `REQUIRED`| not exported |
| Checksum verification         | `v1`      | ✓ HMAC-SHA256 |
| Canonical JSON (key sorting)  | `v1`      | ✓ recursive key sort (RFC 8785 floats remain SHOULD) |
| Key-derivable signing         | `v1`      | ✓ opts / secret_key_base / env |
| Import round-trip fidelity    | `v1`      | ✓ beliefs/desires/goals/shadows/fears restored |
| Slug collision handling       | `v1`      | ✓ (rename / overwrite) |

### Error codes

| Error                                  | Meaning |
|----------------------------------------|---------|
| `:character_not_found`                 | Export target does not exist. |
| `{:invalid_json, reason}`              | Input string is not valid JSON. |
| `:malformed_capsule_structure`         | Missing `format`/`soul`/`checksum`. |
| `:unsupported_capsule_format`          | `format` is not `sovereign_soul_capsule/v1`. |
| `:checksum_mismatch_corrupted_capsule` | Integrity check failed. |
| `{step, failed_value}`                 | Import transaction failed at `step`. |

---

## 9. Verification

The normative behavior is exercised by `test/sovereign_soul_engine/souls/soul_capsule_test.exs`:

- export produces a well-formed capsule with a valid checksum and a `capsule_id`,
- import reconstitutes identity, profile, emotional state, memories, beliefs, desires,
  goals, shadows, fears, and the relationship graph,
- relationship targets resolve by slug; unresolved targets are held in the pending map,
- a capsule verifies only with the same signing key,
- a tampered `soul` payload is rejected with `:checksum_mismatch_corrupted_capsule`.

Run:

```powershell
mix test test/sovereign_soul_engine/souls/soul_capsule_test.exs
```
