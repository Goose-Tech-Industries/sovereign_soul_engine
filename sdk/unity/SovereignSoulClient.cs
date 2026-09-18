using System;
using System.Text;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.Networking;

namespace SovereignSoul
{
    [Serializable] public class ChatRequest
    { public string character_slug; public string message; public string scene_id; }

    [Serializable] public class ChatResponse
    { public string npc_name; public string reply; public string tell; public string audio_url; public bool joined_player; public bool left_player; }

    [Serializable] public class TelemetryRequest
    { public string character_slug; public int heart_rate; public int stress_level; public int fatigue_level; }

    /// <summary>
    /// Synchronous + async REST client for the Sovereign Soul Engine API.
    /// Uses Unity's UnityWebRequest. Authenticates with a tenant API key
    /// (Bearer token). No external dependencies.
    /// </summary>
    public class SovereignSoulClient
    {
        readonly string baseUrl;
        readonly string apiKey;

        public SovereignSoulClient(string baseUrl = "http://localhost:8561", string apiKey = null)
        {
            this.baseUrl = baseUrl.TrimEnd('/');
            this.apiKey = apiKey;
        }

        UnityWebRequest Build(string path, string method, string jsonBody)
        {
            var req = new UnityWebRequest(baseUrl + path, method);
            if (jsonBody != null)
                req.uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(jsonBody));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            if (!string.IsNullOrEmpty(apiKey))
                req.SetRequestHeader("Authorization", "Bearer " + apiKey);
            return req;
        }

        async Task<string> AwaitAsync(UnityWebRequest req)
        {
            req.SendWebRequest();
            while (!req.isDone) await Task.Yield();
            if (req.result != UnityWebRequest.Result.Success)
                throw new Exception($"SSE {req.responseCode} {req.error}: {req.downloadHandler.text}");
            return req.downloadHandler.text;
        }

        /// <summary>Sends a chat message to an NPC and returns the structured reply.</summary>
        public async Task<ChatResponse> ChatAsync(string characterSlug, string message, string sceneId = null)
        {
            string body = JsonUtility.ToJson(new ChatRequest
            { character_slug = characterSlug, message = message, scene_id = sceneId });
            string json = await AwaitAsync(Build("/sse/api/npc_chat", "POST", body));
            return JsonUtility.FromJson<ChatResponse>(json);
        }

        /// <summary>Sends wearable/telemetry biometrics for a player.</summary>
        public async Task<string> SendTelemetryAsync(string playerSlug, int heartRate, int stressLevel, int fatigueLevel = 15)
        {
            string body = JsonUtility.ToJson(new TelemetryRequest
            { character_slug = playerSlug, heart_rate = heartRate, stress_level = stressLevel, fatigue_level = fatigueLevel });
            return await AwaitAsync(Build("/sse/api/telemetry/somatic", "POST", body));
        }

        /// <summary>Fetches the full living-town map (districts + soul positions).</summary>
        public async Task<string> GetTownMapAsync()
        {
            return await AwaitAsync(Build("/sse/api/town/map", "GET", null));
        }

        /// <summary>Fetches the live world feed (recent events, counts).</summary>
        public async Task<string> GetWorldFeedAsync()
        {
            return await AwaitAsync(Build("/sse/api/world/feed", "GET", null));
        }
    }
}
