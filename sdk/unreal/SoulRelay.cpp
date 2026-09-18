#include "SoulRelay.h"

#include "WebSocketsModule.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonReader.h"

// Unreal links OpenSSL (see the "Ssl" module). ED25519 is available in OpenSSL
// 1.1.1+ via EVP.
#include <openssl/evp.h>

// ── Base58BTC & canonical JSON ───────────────────────────────────────────────

namespace
{
    constexpr TCHAR Base58Alphabet[] = TEXT("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz");

    FString Base58Encode(const TArray<uint8>& Data)
    {
        int32 Zeros = 0;
        while (Zeros < Data.Num() && Data[Zeros] == 0) Zeros++;

        TArray<uint8> Digits;
        for (uint8 Byte : Data)
        {
            int32 Carry = Byte;
            for (int32 i = 0; i < Digits.Num(); i++)
            {
                Carry += Digits[i] * 256;
                Digits[i] = Carry % 58;
                Carry /= 58;
            }
            while (Carry > 0)
            {
                Digits.Add(Carry % 58);
                Carry /= 58;
            }
        }

        FString Out = FString::ChrN(Zeros, TCHAR('1'));
        for (int32 i = Digits.Num() - 1; i >= 0; i--)
        {
            Out += Base58Alphabet[Digits[i]];
        }
        return Out;
    }

    // Canonical JSON of a string->string map (sorted keys), matching the
    // server's key-sorted canonical serialization.
    FString CanonicalObject(const TMap<FString, FString>& Map)
    {
        TArray<FString> Keys;
        Map.GetKeys(Keys);
        Keys.Sort();

        FString Out = TEXT("{");
        for (int32 i = 0; i < Keys.Num(); i++)
        {
            if (i > 0) Out += TEXT(",");
            Out += TEXT("\"") + Keys[i] + TEXT("\":\"") + Map[Keys[i]] + TEXT("\"");
        }
        Out += TEXT("}");
        return Out;
    }

    FString JsonEscape(const FString& S)
    {
        FString Out = S;
        Out.ReplaceInline(TEXT("\\"), TEXT("\\\\"));
        Out.ReplaceInline(TEXT("\""), TEXT("\\\""));
        return Out;
    }

    FString GuidStr() { return FGuid::NewGuid().ToString(EGuidFormats::DigitsWithHyphens); }
    FString UtcNowIso() { return FDateTime::UtcNow().ToIso8601(); }

    // Serializes a JSON value to a bare string (no surrounding name).
    FString JsonValueToString(TSharedPtr<FJsonValue> Value)
    {
        if (!Value.IsValid()) return TEXT("null");
        FString Out;
        TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
        FJsonSerializer::Serialize(Value, TEXT(""), Writer);
        return Out;
    }
}

// ── Ed25519 identity ─────────────────────────────────────────────────────────

bool SoulRelay::GenerateKeyPair(TArray<uint8>& OutPrivateKey, TArray<uint8>& OutPublicKey)
{
    OutPrivateKey.SetNum(32);
    for (int32 i = 0; i < 32; i++)
    {
        OutPrivateKey[i] = static_cast<uint8>(FMath::RandRange(0, 255));
    }
    return PublicKeyFromSeed(OutPrivateKey, OutPublicKey);
}

bool SoulRelay::PublicKeyFromSeed(const TArray<uint8>& Seed, TArray<uint8>& OutPublicKey)
{
    if (Seed.Num() != 32) return false;

    EVP_PKEY* Key = EVP_PKEY_new_raw_private_key(EVP_PKEY_ED25519, nullptr, Seed.GetData(), 32);
    if (!Key) return false;

    OutPublicKey.SetNum(32);
    size_t Len = 32;
    bool bOk = EVP_PKEY_get_raw_public_key(Key, OutPublicKey.GetData(), &Len) == 1;
    EVP_PKEY_free(Key);
    return bOk;
}

bool SoulRelay::Sign(const TArray<uint8>& Message, const TArray<uint8>& PrivateKey, TArray<uint8>& OutSignature)
{
    if (PrivateKey.Num() != 32) return false;

    EVP_PKEY* Key = EVP_PKEY_new_raw_private_key(EVP_PKEY_ED25519, nullptr, PrivateKey.GetData(), 32);
    if (!Key) return false;

    EVP_MD_CTX* Ctx = EVP_MD_CTX_new();
    bool bOk = false;
    if (Ctx && EVP_DigestSignInit(Ctx, nullptr, nullptr, nullptr, Key) == 1)
    {
        OutSignature.SetNum(64);
        size_t SigLen = 64;
        bOk = EVP_DigestSign(Ctx, OutSignature.GetData(), &SigLen, Message.GetData(), Message.Num()) == 1;
        if (bOk) OutSignature.SetNum(SigLen);
    }
    if (Ctx) EVP_MD_CTX_free(Ctx);
    EVP_PKEY_free(Key);
    return bOk;
}

bool SoulRelay::Verify(const TArray<uint8>& Message, const TArray<uint8>& Signature, const TArray<uint8>& PublicKey)
{
    if (Signature.Num() != 64 || PublicKey.Num() != 32) return false;

    EVP_PKEY* Key = EVP_PKEY_new_raw_public_key(EVP_PKEY_ED25519, nullptr, PublicKey.GetData(), 32);
    if (!Key) return false;

    EVP_MD_CTX* Ctx = EVP_MD_CTX_new();
    bool bOk = false;
    if (Ctx && EVP_DigestVerifyInit(Ctx, nullptr, nullptr, nullptr, Key) == 1)
    {
        bOk = EVP_DigestVerify(Ctx, Signature.GetData(), Signature.Num(), Message.GetData(), Message.Num()) == 1;
    }
    if (Ctx) EVP_MD_CTX_free(Ctx);
    EVP_PKEY_free(Key);
    return bOk;
}

FString SoulRelay::DidFromPublicKey(const TArray<uint8>& PublicKey)
{
    return TEXT("did:soul:z") + Base58Encode(PublicKey);
}

// ── WebSocket transport ──────────────────────────────────────────────────────

SoulRelay::SoulRelay(const FString& InHost, const FString& InApiKey)
    : Host(InHost), ApiKey(InApiKey)
{
    Host.RemoveFromEnd(TEXT("/"));
}

SoulRelay::~SoulRelay()
{
    Close();
}

void SoulRelay::Connect(TFunction<void()> OnConnected, TFunction<void(const FString&)> OnError)
{
    FString Query = TEXT("vsn=2.0.0");
    if (!ApiKey.IsEmpty())
    {
        Query += TEXT("&api_key=") + FGenericPlatformHttp::UrlEncode(ApiKey);
    }

    Socket = FWebSocketsModule::Get().CreateWebSocket(Host + TEXT("/sse/socket/websocket?") + Query);

    Socket->OnConnected().AddLambda([OnConnected]() { if (OnConnected) OnConnected(); });
    Socket->OnConnectionError().AddLambda([OnError](const FString& Error) { if (OnError) OnError(Error); });
    Socket->OnMessage().AddLambda([this](const FString& Message) { HandleMessage(Message); });

    Socket->Connect();
}

void SoulRelay::Close()
{
    if (Socket.IsValid() && Socket->IsConnected())
    {
        Socket->Close();
    }
}

void SoulRelay::Join(const FString& Topic, const FString& Did, TFunction<void(int64)> OnJoined)
{
    int64 Ref = ++RefCounter;
    FString Payload = TEXT("{\"did\":\"") + JsonEscape(Did) + TEXT("\"}");
    Socket->Send(FString::Printf(TEXT("[null,%lld,\"%s\",\"phx_join\",%s]"), Ref, *Topic, *Payload));
    if (OnJoined) OnJoined(Ref);
}

void SoulRelay::SendEnvelope(const FString& Topic, int64 JoinRef, const FString& FromDid,
                             const FString& Type, const FString& ToDid,
                             const TMap<FString, FString>& Payload,
                             const TArray<uint8>& PrivateKey,
                             TFunction<void(bool)> OnSent)
{
    FString Id = GuidStr();
    FString Ts = UtcNowIso();
    FString Nonce = GuidStr();
    FString PayloadJson = CanonicalObject(Payload);
    FString ToJson = ToDid.IsEmpty() ? TEXT("null") : FString::Printf(TEXT("\"%s\""), *ToDid);

    // Canonical signing payload over the fixed fields (sorted, RFC-0002 §4).
    FString Signing = FString::Printf(
        TEXT("{\"from\":\"%s\",\"id\":\"%s\",\"nonce\":\"%s\",\"payload\":%s,\"prev\":null,\"to\":%s,\"ts\":\"%s\",\"type\":\"%s\",\"v\":1}"),
        *FromDid, *Id, *Nonce, *PayloadJson, *ToJson, *Ts, *Type);

    FTCHARToUTF8 SigningUtf8(*Signing);
    TArray<uint8> MessageBytes;
    MessageBytes.Append(reinterpret_cast<const uint8*>(SigningUtf8.Get()), SigningUtf8.Length());

    TArray<uint8> Signature;
    if (!Sign(MessageBytes, PrivateKey, Signature))
    {
        if (OnSent) OnSent(false);
        return;
    }

    FString Envelope = FString::Printf(
        TEXT("{\"v\":1,\"type\":\"%s\",\"from\":\"%s\",\"to\":%s,\"id\":\"%s\",\"ts\":\"%s\",\"nonce\":\"%s\",\"prev\":null,\"payload\":%s,\"sig\":\"%s\"}"),
        *Type, *FromDid, *ToJson, *Id, *Ts, *Nonce, *PayloadJson, *Base58Encode(Signature));

    int64 Ref = ++RefCounter;
    Socket->Send(FString::Printf(TEXT("[%lld,%lld,\"%s\",\"envelope\",%s]"), JoinRef, Ref, *Topic, *Envelope));
    if (OnSent) OnSent(true);
}

void SoulRelay::HandleMessage(const FString& Message)
{
    TSharedPtr<FJsonValue> Root;
    TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(Message);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid()) return;

    const TArray<TSharedPtr<FJsonValue>>* Arr = nullptr;
    if (!Root->TryGetArray(Arr) || Arr->Num() < 5) return;

    FString Topic = (*Arr)[2]->AsString();
    FString Event = (*Arr)[3]->AsString();

    if (Event == TEXT("phx_reply")) return;

    FString PayloadJson = JsonValueToString((*Arr)[4]);
    if (OnPush) OnPush(Topic, Event, PayloadJson);
}
