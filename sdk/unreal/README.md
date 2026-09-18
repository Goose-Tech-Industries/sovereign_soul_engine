# Sovereign Soul Engine — Unreal SDK

Drop-in C++ client for embedding Sovereign Soul NPCs in an Unreal Engine game.

## Files

| File | Purpose |
|---|---|
| `SovereignSoul.h/.cpp` | REST API — chat, telemetry, town map, world feed (tenant key auth). |
| `SoulRelay.h/.cpp` | WebSocket relay — Ed25519 identity, `did:soul:` DIDs, signed envelopes. |

## Setup

Add the modules to your `*.Build.cs`:

```cpp
PublicDependencyModuleNames.AddRange({
    "Core", "Http", "Json", "WebSockets", "Ssl"
});
```

Add both `.cpp` files to your module, and set `bEnableExceptions` if your target
doesn't enable them (the OpenSSL EVP calls don't throw, but Unreal's HTTP/JSON
helpers expect the usual setup).

## Chat (REST)

```cpp
SovereignSoul* Sse = new SovereignSoul(
    TEXT("http://localhost:8561"),
    TEXT("sse_live_your_tenant_key"));

Sse->Chat(TEXT("maya"), TEXT("The forge is cold."),
    [](bool bOk, const FString& Json)
    {
        if (bOk) UE_LOG(LogTemp, Log, TEXT("NPC: %s"), *Json);
    });
```

## Relay (identity + gossip)

```cpp
SoulRelay* Relay = new SoulRelay(TEXT("ws://localhost:8561"));

TArray<uint8> PrivKey, PubKey;
SoulRelay::GenerateKeyPair(PrivKey, PubKey);
FString Did = SoulRelay::DidFromPublicKey(PubKey);

Relay->OnPush = [](const FString& Topic, const FString& Event, const FString& Payload)
{
    UE_LOG(LogTemp, Log, TEXT("[%s] %s: %s"), *Topic, *Event, *Payload);
};

Relay->Connect();

int64 JoinRef = 0;
Relay->Join(TEXT("world:sovereign-society"), Did,
    [&](int64 Ref) { JoinRef = Ref; });

TMap<FString, FString> Payload;
Payload.Add(TEXT("rumor"), TEXT("the square is restless"));
Relay->SendEnvelope(TEXT("world:sovereign-society"), JoinRef, Did,
    TEXT("gossip"), TEXT(""), Payload, PrivKey);
```

## Notes

- Chat/telemetry use a **tenant API key** (Bearer token). Provision one with
  `mix sse.create_tenant`.
- Ed25519 uses OpenSSL's EVP (Unreal links OpenSSL via the `Ssl` module). Works
  on OpenSSL 1.1.1 and 3.x.
- Mature/adult content tiers are only available against a **local/open-weight**
  model deployment; cloud model providers apply their own content policies.
- The envelope payload is a `TMap<FString, FString>` (string→string), canonicalized
  with sorted keys so the signature matches the server. For nested payloads,
  serialize to canonical JSON yourself and sign with `SoulRelay::Sign` directly.
