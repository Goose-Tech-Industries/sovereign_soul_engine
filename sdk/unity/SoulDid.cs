using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;

namespace SovereignSoul
{
    /// <summary>Bitcoin Base58 (Base58BTC) encoding, no multibase prefix.</summary>
    public static class Base58
    {
        const string Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

        public static string Encode(byte[] data)
        {
            if (data == null || data.Length == 0) return "";

            int zeros = 0;
            while (zeros < data.Length && data[zeros] == 0) zeros++;

            var digits = new List<byte>();
            foreach (byte b in data)
            {
                int carry = b;
                for (int i = 0; i < digits.Count; i++)
                {
                    carry += digits[i] * 256;
                    digits[i] = (byte)(carry % 58);
                    carry /= 58;
                }
                while (carry > 0)
                {
                    digits.Add((byte)(carry % 58));
                    carry /= 58;
                }
            }

            var sb = new StringBuilder(new string('1', zeros));
            for (int i = digits.Count - 1; i >= 0; i--) sb.Append(Alphabet[digits[i]]);
            return sb.ToString();
        }
    }

    /// <summary>
    /// Canonical JSON (RFC 8785-style key sorting) so signatures byte-match the
    /// Elixir/Node reference implementations.
    /// </summary>
    public static class Jcs
    {
        public static string Serialize(object value)
        {
            var sb = new StringBuilder();
            Write(sb, value);
            return sb.ToString();
        }

        static void Write(StringBuilder sb, object v)
        {
            if (v == null) { sb.Append("null"); return; }
            switch (v)
            {
                case bool b: sb.Append(b ? "true" : "false"); return;
                case int i: sb.Append(i); return;
                case long l: sb.Append(l); return;
                case double d: sb.Append(Number(d)); return;
                case string s: sb.Append(JsonEscape(s)); return;
                case IDictionary<string, object> map:
                    sb.Append('{');
                    bool first = true;
                    foreach (var kv in map.OrderBy(kv => kv.Key, StringComparer.Ordinal))
                    {
                        if (!first) sb.Append(',');
                        sb.Append(JsonEscape(kv.Key)).Append(':');
                        Write(sb, kv.Value);
                        first = false;
                    }
                    sb.Append('}');
                    return;
                case System.Collections.IEnumerable list:
                    sb.Append('[');
                    bool firstItem = true;
                    foreach (var item in list)
                    {
                        if (!firstItem) sb.Append(',');
                        Write(sb, item);
                        firstItem = false;
                    }
                    sb.Append(']');
                    return;
                default:
                    throw new ArgumentException("JCS: unsupported type " + v.GetType());
            }
        }

        static string Number(double d)
        {
            if (d == Math.Floor(d) && Math.Abs(d) < 1e21)
                return ((long)d).ToString(CultureInfo.InvariantCulture);
            return d.ToString("R", CultureInfo.InvariantCulture);
        }

        static string JsonEscape(string s)
        {
            var sb = new StringBuilder(s.Length + 2);
            sb.Append('"');
            foreach (char c in s)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4"));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
            return sb.ToString();
        }
    }

    /// <summary>Sovereign identity: DID formatting and signed relay envelopes.</summary>
    public static class SoulDid
    {
        public static string FromPublicKey(byte[] publicKey) =>
            "did:soul:z" + Base58.Encode(publicKey);

        static string NewId() => Guid.NewGuid().ToString();
        static string Now() => DateTime.UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'");

        static readonly string[] SigningKeys =
            { "v", "type", "from", "to", "id", "ts", "nonce", "prev", "payload" };

        /// <summary>Builds an unsigned envelope (RFC-0002 §4).</summary>
        public static Dictionary<string, object> BuildEnvelope(
            string fromDid, string type, string toDid, Dictionary<string, object> payload, string prev)
        {
            return new Dictionary<string, object>
            {
                ["v"] = 1,
                ["type"] = type,
                ["from"] = fromDid,
                ["to"] = toDid,
                ["id"] = NewId(),
                ["ts"] = Now(),
                ["nonce"] = NewId(),
                ["prev"] = prev,
                ["payload"] = payload ?? new Dictionary<string, object>()
            };
        }

        static Dictionary<string, object> SigningFields(Dictionary<string, object> envelope)
        {
            var fields = new Dictionary<string, object>();
            foreach (var k in SigningKeys)
                fields[k] = envelope.TryGetValue(k, out var v) ? v : null;
            return fields;
        }

        /// <summary>Signs an envelope in place, adding the "sig" field (Base58BTC).</summary>
        public static void SignEnvelope(Dictionary<string, object> envelope, byte[] privateKey)
        {
            string canonical = Jcs.Serialize(SigningFields(envelope));
            byte[] sig = Ed25519.Sign(Encoding.UTF8.GetBytes(canonical), privateKey);
            envelope["sig"] = Base58.Encode(sig);
        }
    }
}
