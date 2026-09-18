#pragma once

#include "CoreMinimal.h"
#include "IWebSocket.h"

/**
 * Soul Society relay client — Ed25519 identity, `did:soul:` DIDs, signed
 * envelopes, and the Phoenix Channels v2 WebSocket transport.
 *
 * Requires the "WebSockets", "Ssl" (for OpenSSL), and "Json" modules:
 *   PublicDependencyModuleNames.AddRange({"Core", "WebSockets", "Ssl", "Json"});
 */
class SOVEREIGNSOUL_API SoulRelay
{
public:
    /** Generates a fresh keypair. Outputs 32-byte private seed and 32-byte public key. */
    static bool GenerateKeyPair(TArray<uint8>& OutPrivateKey, TArray<uint8>& OutPublicKey);

    /** Derives the 32-byte public key from a 32-byte private seed. */
    static bool PublicKeyFromSeed(const TArray<uint8>& Seed, TArray<uint8>& OutPublicKey);

    /** Signs a message (Ed25519). Returns a 64-byte signature. */
    static bool Sign(const TArray<uint8>& Message, const TArray<uint8>& PrivateKey, TArray<uint8>& OutSignature);

    /** Verifies a 64-byte signature against a 32-byte public key. */
    static bool Verify(const TArray<uint8>& Message, const TArray<uint8>& Signature, const TArray<uint8>& PublicKey);

    /** Formats a `did:soul:z<base58btc>` DID from a 32-byte public key. */
    static FString DidFromPublicKey(const TArray<uint8>& PublicKey);

    SoulRelay(const FString& InHost, const FString& InApiKey = FString());
    ~SoulRelay();

    /** Connects the WebSocket. OnConnected fires once the handshake completes. */
    void Connect(TFunction<void()> OnConnected = nullptr, TFunction<void(const FString&)> OnError = nullptr);

    void Close();

    /** Joins a topic (e.g. "world:sovereign-society"). Returns the join ref. */
    void Join(const FString& Topic, const FString& Did, TFunction<void(int64)> OnJoined);

    /**
     * Sends a signed envelope on a topic. The payload is a string->string map
     * canonicalized with sorted keys so the signature matches the server.
     */
    void SendEnvelope(const FString& Topic, int64 JoinRef, const FString& FromDid,
                      const FString& Type, const FString& ToDid,
                      const TMap<FString, FString>& Payload,
                      const TArray<uint8>& PrivateKey,
                      TFunction<void(bool)> OnSent = nullptr);

    /** Fires for every server push: (topic, event, payload-json). */
    TFunction<void(const FString&, const FString&, const FString&)> OnPush;

private:
    TSharedPtr<IWebSocket> Socket;
    FString Host;
    FString ApiKey;
    int64 RefCounter = 0;

    void HandleMessage(const FString& Message);
};
