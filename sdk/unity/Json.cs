using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace SovereignSoul
{
    /// <summary>
    /// Minimal dependency-free JSON parser (objects, arrays, strings, numbers,
    /// booleans, null). Serialization is provided by <see cref="Jcs"/>.
    /// </summary>
    public static class Json
    {
        public static object Parse(string text)
        {
            int i = 0;
            object value = ParseValue(text, ref i);
            SkipWhitespace(text, ref i);
            if (i != text.Length) throw new FormatException("trailing content in JSON");
            return value;
        }

        static object ParseValue(string s, ref int i)
        {
            SkipWhitespace(s, ref i);
            if (i >= s.Length) throw new FormatException("unexpected end of JSON");
            char c = s[i];
            switch (c)
            {
                case '{': return ParseObject(s, ref i);
                case '[': return ParseArray(s, ref i);
                case '"': return ParseString(s, ref i);
                case 't': Expect(s, ref i, "true"); return true;
                case 'f': Expect(s, ref i, "false"); return false;
                case 'n': Expect(s, ref i, "null"); return null;
                default: return ParseNumber(s, ref i);
            }
        }

        static Dictionary<string, object> ParseObject(string s, ref int i)
        {
            var map = new Dictionary<string, object>();
            i++; // consume '{'
            SkipWhitespace(s, ref i);
            if (s[i] == '}') { i++; return map; }
            while (true)
            {
                SkipWhitespace(s, ref i);
                string key = ParseString(s, ref i);
                SkipWhitespace(s, ref i);
                if (s[i] != ':') throw new FormatException("expected ':'");
                i++;
                map[key] = ParseValue(s, ref i);
                SkipWhitespace(s, ref i);
                if (s[i] == '}') { i++; return map; }
                if (s[i] != ',') throw new FormatException("expected ',' or '}'");
                i++;
            }
        }

        static List<object> ParseArray(string s, ref int i)
        {
            var list = new List<object>();
            i++; // consume '['
            SkipWhitespace(s, ref i);
            if (s[i] == ']') { i++; return list; }
            while (true)
            {
                list.Add(ParseValue(s, ref i));
                SkipWhitespace(s, ref i);
                if (s[i] == ']') { i++; return list; }
                if (s[i] != ',') throw new FormatException("expected ',' or ']'");
                i++;
            }
        }

        static string ParseString(string s, ref int i)
        {
            i++; // consume '"'
            var sb = new StringBuilder();
            while (true)
            {
                if (i >= s.Length) throw new FormatException("unterminated string");
                char c = s[i++];
                if (c == '"') return sb.ToString();
                if (c == '\\')
                {
                    char e = s[i++];
                    switch (e)
                    {
                        case '"': sb.Append('"'); break;
                        case '\\': sb.Append('\\'); break;
                        case '/': sb.Append('/'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'u':
                            sb.Append((char)ushort.Parse(s.Substring(i, 4), NumberStyles.HexNumber));
                            i += 4;
                            break;
                        default: throw new FormatException("bad escape");
                    }
                }
                else sb.Append(c);
            }
        }

        static object ParseNumber(string s, ref int i)
        {
            int start = i;
            while (i < s.Length && (char.IsDigit(s[i]) || s[i] == '-' || s[i] == '+' || s[i] == '.' || s[i] == 'e' || s[i] == 'E'))
                i++;
            string token = s.Substring(start, i - start);
            if (token.Contains('.') || token.Contains('e') || token.Contains('E'))
                return double.Parse(token, CultureInfo.InvariantCulture);
            return long.Parse(token, CultureInfo.InvariantCulture);
        }

        static void Expect(string s, ref int i, string word)
        {
            if (i + word.Length > s.Length || s.Substring(i, word.Length) != word)
                throw new FormatException("unexpected token");
            i += word.Length;
        }

        static void SkipWhitespace(string s, ref int i)
        {
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
        }
    }
}
