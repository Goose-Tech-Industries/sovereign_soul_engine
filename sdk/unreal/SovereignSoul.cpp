#include "SovereignSoul.h"

#include "HttpModule.h"
#include "Interfaces/IHttpRequest.h"
#include "Interfaces/IHttpResponse.h"
#include "Serialization/JsonSerializer.h"
#include "Serialization/JsonWriter.h"

SovereignSoul::SovereignSoul(const FString& InBaseUrl, const FString& InApiKey)
    : BaseUrl(InBaseUrl), ApiKey(InApiKey)
{
    BaseUrl.RemoveFromEnd(TEXT("/"));
}

namespace
{
    FString MakeObject(TFunction<void(TSharedRef<FJsonObject>)> Populate)
    {
        TSharedRef<FJsonObject> Obj = MakeShareable(new FJsonObject());
        Populate(Obj);
        FString Out;
        TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&Out);
        FJsonSerializer::Serialize(Obj, Writer);
        return Out;
    }
}

void SovereignSoul::Chat(const FString& CharacterSlug, const FString& Message,
                         TFunction<void(bool, const FString&)> OnComplete)
{
    FString Body = MakeObject([&](TSharedRef<FJsonObject> O)
    {
        O->SetStringField(TEXT("character_slug"), CharacterSlug);
        O->SetStringField(TEXT("message"), Message);
    });
    Send(TEXT("/sse/api/npc_chat"), TEXT("POST"), Body, OnComplete);
}

void SovereignSoul::SendTelemetry(const FString& PlayerSlug, int32 HeartRate, int32 StressLevel, int32 FatigueLevel,
                                  TFunction<void(bool, const FString&)> OnComplete)
{
    FString Body = MakeObject([&](TSharedRef<FJsonObject> O)
    {
        O->SetStringField(TEXT("character_slug"), PlayerSlug);
        O->SetNumberField(TEXT("heart_rate"), HeartRate);
        O->SetNumberField(TEXT("stress_level"), StressLevel);
        O->SetNumberField(TEXT("fatigue_level"), FatigueLevel);
    });
    Send(TEXT("/sse/api/telemetry/somatic"), TEXT("POST"), Body, OnComplete);
}

void SovereignSoul::GetTownMap(TFunction<void(bool, const FString&)> OnComplete)
{
    Send(TEXT("/sse/api/town/map"), TEXT("GET"), FString(), OnComplete);
}

void SovereignSoul::GetWorldFeed(TFunction<void(bool, const FString&)> OnComplete)
{
    Send(TEXT("/sse/api/world/feed"), TEXT("GET"), FString(), OnComplete);
}

void SovereignSoul::Send(const FString& Path, const FString& Verb, const FString& JsonBody,
                         TFunction<void(bool, const FString&)> OnComplete)
{
    TSharedRef<IHttpRequest, ESPMode::ThreadSafe> Request = FHttpModule::Get().CreateRequest();
    Request->SetURL(BaseUrl + Path);
    Request->SetVerb(Verb);
    Request->SetHeader(TEXT("Content-Type"), TEXT("application/json"));
    if (!ApiKey.IsEmpty())
    {
        Request->SetHeader(TEXT("Authorization"), FString::Printf(TEXT("Bearer %s"), *ApiKey));
    }
    if (!JsonBody.IsEmpty())
    {
        Request->SetContentAsString(JsonBody);
    }

    Request->OnProcessRequestComplete().BindLambda(
        [OnComplete](FHttpRequestPtr, FHttpResponsePtr Response, bool bSuccess)
        {
            if (bSuccess && Response.IsValid())
            {
                OnComplete(true, Response->GetContentAsString());
            }
            else
            {
                OnComplete(false, FString());
            }
        });

    Request->ProcessRequest();
}
