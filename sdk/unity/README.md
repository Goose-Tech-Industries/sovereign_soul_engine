# Sovereign Soul Engine — Unity SDK

Drop-in C# client for embedding Sovereign Soul NPCs in a Unity game. No external
dependencies.

## Files

| File | Purpose |
|---|---|
| `SovereignSoulClient.cs` | REST API — chat, telemetry, town map, world feed (tenant API key auth). |
| `RelayClient.cs` | WebSocket relay — join topics, send signed envelopes, receive pushes. |
| `SoulIdentity.cs` | Self-contained Ed25519 (RFC 8032) with an RFC test vector. |
| `SoulDid.cs` | Base58BTC, `did:soul:` formatting, canonical JSON, signed envelopes. |
| `Json.cs` | Minimal dependency-free JSON parser. |

Drop all files into an `Editor`/`Runtime` folder (any `asmdef` works).

## Quick start — chat

```csharp
var sse = new SovereignSoul.SovereignSoulClient(
    baseUrl: "http://localhost:8561",
    apiKey: "sse_live_your_tenant_key");

var reply = await sse.ChatAsync(characterSlug: "maya", message: "The forge is cold.");
Debug.Log($"{reply.npc_name}: {reply.reply}");
```

## Relay / Soul Society (identity + gossip)

```csharp
var (privateKey, publicKey) = SovereignSoul.Ed25519.GenerateKeyPair();
string did = SovereignSoul.SoulDid.FromPublicKey(publicKey);

var relay = new SovereignSoul.RelayClient("ws://localhost:8561");
await relay.ConnectAsync();
long joinRef = await relay.JoinAsync("world:sovereign-society", $"{{\"did\":\"{did}\"}}");

var envelope = SovereignSoul.SoulDid.BuildEnvelope(
    fromDid: did, type: "gossip", toDid: null,
    payload: new Dictionary<string, object> { ["rumor"] = "the square is restless" },
    prev: null);
SovereignSoul.SoulDid.SignEnvelope(envelope, privateKey);

await relay.SendEnvelopeAsync("world:sovereign-society", joinRef, envelope);
```

## Verify the crypto on your platform

Call `SovereignSoul.Ed25519.SelfTest()` once at startup in the editor. It checks
signing/verification against RFC 8032 test vector #1 — if it returns `false`, the
BigInteger port misbehaved on your runtime and you should not ship signatures.

## Notes

- Chat/telemetry use a **tenant API key** (Bearer token). Provision one with
  `mix sse.create_tenant`.
- Relay envelopes are signed with a soul's Ed25519 key; in production the socket
  also requires the tenant key in the `api_key` connect parameter.
- Mature/adult content tiers are only available against a **local/open-weight**
  model deployment; cloud model providers apply their own content policies.
