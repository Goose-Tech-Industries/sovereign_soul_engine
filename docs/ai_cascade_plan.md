# SovereignSoulEngine — AI Provider Cascade & Fallback Blueprint

We require the LLM client in Sovereign Soul Engine (`SovereignSoulEngine.LLM`) to utilize the same multi-provider fallback cascade as Goose Panel. This prevents a single API outage from breaking live character brains.

---

## 1. Provider Cascade Order

```text
Anthropic (Claude) ──> OpenAI (GPT) ──> DeepSeek ──> xAI (Grok) ──> Google (Gemini)
```

The system will cascade through the keys, using the first valid key found in:
1. System Environment variables (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.)
2. Local database/configuration.

---

## 2. API Implementations

### Anthropic (Claude)
*   **URL:** `https://api.anthropic.com/v1/messages`
*   **Default Model:** `claude-haiku-4-5-20251001` (or `claude-sonnet-4-6` for complex scenes)
*   **Headers:** `x-api-key`, `anthropic-version: 2023-06-01`

### OpenAI-Compatible (OpenAI, DeepSeek, xAI)
*   **Endpoints:**
    *   OpenAI: `https://api.openai.com/v1/chat/completions` (Model: `gpt-4o-mini`)
    *   DeepSeek: `https://api.deepseek.com/chat/completions` (Model: `deepseek-chat`)
    *   xAI: `https://api.x.ai/v1/chat/completions` (Model: `grok-4-fast`)
*   **Headers:** `authorization: Bearer KEY`

### Google (Gemini)
*   **URL:** `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
*   **Default Model:** `gemini-2.0-flash`
*   **API Key:** Passed as a query parameter `?key=KEY`

---

## 3. Structured JSON Constraint

The LLM client must enforce a strict JSON Schema requirement across all models to ensure we get valid, un-hallucinated data back for the Soul Core:

```json
{
  "public_speech": "String",
  "private_thought": "String",
  "tone": "String",
  "motivation": "String",
  "target_character_id": "UUID String",
  "proposed_action": {
    "type": "String",
    "confidence": 0.0,
    "reason": "String"
  },
  "memory_candidates": [
    {
      "category": "String",
      "summary": "String",
      "importance": 0,
      "emotional_intensity": 0,
      "valence": 0.0,
      "tags": ["String"]
    }
  ]
}
```

The Elixir client will validate this JSON, fall back to default empty structs upon format failure, and sanitize inputs to prevent prompt injection.
