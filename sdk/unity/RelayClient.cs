using System;
using System.Collections.Generic;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace SovereignSoul
{
    /// <summary>
    /// Phoenix Channels v2 WebSocket client for the Soul Society relay
    /// (`/sse/socket`). Joins topics, sends signed envelopes, and surfaces
    /// server pushes. Dependency-free (uses System.Net.WebSockets).
    /// </summary>
    public class RelayClient
    {
        readonly string url;

        ClientWebSocket ws;
        CancellationTokenSource cts;
        long refCounter;
        readonly Dictionary<long, TaskCompletionSource<bool>> pending = new();

        /// <summary>Invoked with (topic, event, payload) for every server push.</summary>
        public Action<string, string, object> OnPush;

        public RelayClient(string host = "ws://localhost:8561", string apiKey = null)
        {
            string baseUrl = host.TrimEnd('/');
            string query = "vsn=2.0.0" +
                (string.IsNullOrEmpty(apiKey) ? "" : "&api_key=" + Uri.EscapeDataString(apiKey));
            url = $"{baseUrl}/sse/socket/websocket?{query}";
        }

        public async Task ConnectAsync()
        {
            ws = new ClientWebSocket();
            cts = new CancellationTokenSource();
            await ws.ConnectAsync(new Uri(url), cts.Token);
            _ = ReceiveLoop();
        }

        public async Task CloseAsync()
        {
            try
            {
                cts?.Cancel();
                await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "bye", CancellationToken.None);
            }
            catch { /* already closed */ }
        }

        long NextRef() => Interlocked.Increment(ref refCounter);

        Task<bool> SendAndAwait(string frame, long r)
        {
            var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            pending[r] = tcs;
            return SendFrame(frame).ContinueWith(_ => tcs.Task).Unwrap();
        }

        async Task SendFrame(string text)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(text);
            await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, cts.Token);
        }

        async Task ReceiveLoop()
        {
            var buffer = new byte[65536];
            var sb = new StringBuilder();
            try
            {
                while (ws.State == WebSocketState.Open)
                {
                    var result = await ws.ReceiveAsync(new ArraySegment<byte>(buffer), cts.Token);
                    if (result.MessageType == WebSocketMessageType.Close) break;

                    sb.Append(Encoding.UTF8.GetString(buffer, 0, result.Count));
                    if (!result.EndOfMessage) continue;

                    HandleMessage(sb.ToString());
                    sb.Clear();
                }
            }
            catch { /* socket closed */ }
        }

        void HandleMessage(string text)
        {
            var arr = (List<object>)Json.Parse(text);
            object refObj = arr[1];
            string topic = (string)arr[2];
            string ev = (string)arr[3];
            object payload = arr[4];

            if (ev == "phx_reply" && refObj is long lr && pending.TryGetValue(lr, out var tcs))
            {
                pending.Remove(lr);
                tcs.TrySetResult(true);
                return;
            }

            OnPush?.Invoke(topic, ev, payload);
        }

        /// <summary>
        /// Joins a topic. Returns the join ref, which must be supplied to
        /// <see cref="SendEnvelopeAsync"/> for that topic's envelopes.
        /// </summary>
        public async Task<long> JoinAsync(string topic, string payloadJson = "{}")
        {
            long r = NextRef();
            await SendAndAwait($"[null,{r},\"{topic}\",\"phx_join\",{payloadJson}]", r);
            return r;
        }

        /// <summary>Sends a signed envelope on a topic and awaits the relay reply.</summary>
        public async Task SendEnvelopeAsync(string topic, long joinRef, Dictionary<string, object> envelope)
        {
            long r = NextRef();
            await SendAndAwait($"[{joinRef},{r},\"{topic}\",\"envelope\",{Jcs.Serialize(envelope)}]", r);
        }
    }
}
