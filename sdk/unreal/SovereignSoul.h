#pragma once

#include "CoreMinimal.h"
#include "Http.h"

/**
 * REST client for the Sovereign Soul Engine API.
 *
 * Requires the "Http" and "Json" modules in your Build.cs:
 *   PublicDependencyModuleNames.AddRange({"Core", "Http", "Json"});
 */
class SOVEREIGNSOUL_API SovereignSoul
{
public:
    SovereignSoul(const FString& InBaseUrl, const FString& InApiKey);

    /** POST /sse/api/npc_chat — send a message to an NPC. */
    void Chat(const FString& CharacterSlug, const FString& Message,
              TFunction<void(bool, const FString&)> OnComplete);

    /** POST /sse/api/telemetry/somatic — push wearable/biometric telemetry. */
    void SendTelemetry(const FString& PlayerSlug, int32 HeartRate, int32 StressLevel, int32 FatigueLevel,
                       TFunction<void(bool, const FString&)> OnComplete);

    /** GET /sse/api/town/map — fetch the living-town map JSON. */
    void GetTownMap(TFunction<void(bool, const FString&)> OnComplete);

    /** GET /sse/api/world/feed — fetch the live world feed JSON. */
    void GetWorldFeed(TFunction<void(bool, const FString&)> OnComplete);

private:
    FString BaseUrl;
    FString ApiKey;

    void Send(const FString& Path, const FString& Verb, const FString& JsonBody,
              TFunction<void(bool, const FString&)> OnComplete);
};
