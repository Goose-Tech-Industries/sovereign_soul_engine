defmodule SovereignSoulEngine.LLM.AnthropicProvider do
  @moduledoc """
  Anthropic (Claude) LLM provider.

  Uses the Anthropic Messages API.
  Requires the `ANTHROPIC_API_KEY` environment variable.

  API docs: https://docs.anthropic.com/en/api/messages
  """

  @behaviour SovereignSoulEngine.LLM.Provider

  require Logger

  @base_url "https://api.anthropic.com/v1/messages"
  @default_model "claude-haiku-4-5-20251001"
  @anthropic_version "2023-06-01"

  @impl true
  def provider_name, do: "anthropic"

  @impl true
  def health do
    if api_key() do
      {:ok, %{status: "configured", model: @default_model}}
    else
      {:error, "ANTHROPIC_API_KEY not configured"}
    end
  end

  @impl true
  def respond(input) do
    with {:ok, key} <- require_api_key(),
         {:ok, body} <- build_request_body(input),
         {:ok, response} <- send_request(key, body),
         {:ok, parsed} <- parse_response(response) do
      {:ok, parsed}
    end
  end

  # ── Request Building ─────────────────────────────────────────

  defp build_request_body(%{messages: messages} = input) do
    system = input[:system] || input["system"]
    max_tokens = input[:max_tokens] || input["max_tokens"] || 4096

    body = %{
      model: @default_model,
      max_tokens: max_tokens,
      messages: build_messages(messages)
    }

    body =
      if system do
        Map.put(body, :system, system)
      else
        body
      end

    {:ok, body}
  end

  defp build_request_body(_input) do
    {:error, "missing required :messages key in input"}
  end

  defp build_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      role = if is_map(msg), do: msg[:role] || msg["role"] || "user", else: "user"
      content = if is_map(msg), do: msg[:content] || msg["content"] || "", else: ""
      %{role: role, content: content}
    end)
  end

  # ── HTTP Request ─────────────────────────────────────────────

  defp send_request(api_key, body) do
    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]

    case Req.post(@base_url,
           json: body,
           headers: headers,
           max_retries: 1,
           receive_timeout: 25_000
         ) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: response_body}} ->
        Logger.warning("Anthropic API returned status #{status}: #{inspect(response_body)}")
        {:error, "anthropic_http_#{status}"}

      {:error, %{reason: reason}} ->
        Logger.warning("Anthropic API request failed: #{inspect(reason)}")
        {:error, "anthropic_request_failed: #{inspect(reason)}"}
    end
  end

  # ── Response Parsing ─────────────────────────────────────────

  defp parse_response(%{"content" => [%{"text" => text} | _]}) do
    parse_text_content(text)
  end

  defp parse_response(%{"content" => text}) when is_binary(text) do
    parse_text_content(text)
  end

  defp parse_response(response) do
    Logger.warning("Unexpected Anthropic response shape: #{inspect(response)}")
    {:error, "unexpected_response_shape"}
  end

  defp parse_text_content(text) do
    case Jason.decode(text) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
        build_fallback_response(text)
    end
  end

  defp build_fallback_response(text) do
    {:ok,
     %{
       public_speech: String.slice(text, 0, 5000),
       private_thought: "",
       tone: "neutral",
       motivation: "unknown",
       target_character_id: nil,
       proposed_action: nil,
       memory_candidates: [],
       relationship_signals: nil
     }}
  end

  # ── Configuration ────────────────────────────────────────────

  defp require_api_key do
    case api_key() do
      nil -> {:error, "ANTHROPIC_API_KEY not configured"}
      key -> {:ok, key}
    end
  end

  defp api_key do
    System.get_env("ANTHROPIC_API_KEY")
  end
end
