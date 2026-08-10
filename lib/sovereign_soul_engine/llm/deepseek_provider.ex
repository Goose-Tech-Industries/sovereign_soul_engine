defmodule SovereignSoulEngine.LLM.DeepSeekProvider do
  @moduledoc """
  DeepSeek LLM provider.

  Uses the DeepSeek Chat Completions API (OpenAI-compatible).
  Requires the `DEEPSEEK_API_KEY` environment variable.
  """

  @behaviour SovereignSoulEngine.LLM.Provider

  require Logger

  @base_url "https://api.deepseek.com/chat/completions"
  # "deepseek-chat" was retired — DeepSeek now only accepts deepseek-v4-pro
  # or deepseek-v4-flash. Flash matches this provider's use (frequent,
  # lightweight NPC dialogue calls, not a heavy reasoning workload).
  @default_model "deepseek-v4-flash"

  @impl true
  def provider_name, do: "deepseek"

  @impl true
  def health do
    if api_key([]) do
      {:ok, %{status: "configured", model: @default_model}}
    else
      {:error, "DEEPSEEK_API_KEY not configured"}
    end
  end

  @impl true
  def respond(input, opts \\ []) do
    with {:ok, key} <- require_api_key(opts),
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

    msgs = build_messages(messages, system)

    body = %{
      model: @default_model,
      messages: msgs,
      max_tokens: max_tokens,
      response_format: %{type: "json_object"}
    }

    {:ok, body}
  end

  defp build_request_body(_input) do
    {:error, "missing required :messages key in input"}
  end

  defp build_messages(messages, nil) when is_list(messages) do
    Enum.map(messages, fn msg ->
      role = if is_map(msg), do: msg[:role] || msg["role"] || "user", else: "user"
      content = if is_map(msg), do: msg[:content] || msg["content"] || "", else: ""
      %{role: role, content: content}
    end)
  end

  defp build_messages(messages, system) when is_list(messages) do
    [
      %{role: "system", content: system}
      | Enum.map(messages, fn msg ->
          role = if is_map(msg), do: msg[:role] || msg["role"] || "user", else: "user"
          content = if is_map(msg), do: msg[:content] || msg["content"] || "", else: ""
          %{role: role, content: content}
        end)
    ]
  end

  # ── HTTP Request ─────────────────────────────────────────────

  defp send_request(api_key, body) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
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
        Logger.warning("DeepSeek API returned status #{status}: #{inspect(response_body)}")
        {:error, "deepseek_http_#{status}"}

      {:error, %{reason: reason}} ->
        Logger.warning("DeepSeek API request failed: #{inspect(reason)}")
        {:error, "deepseek_request_failed: #{inspect(reason)}"}
    end
  end

  # ── Response Parsing ─────────────────────────────────────────

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    case Jason.decode(content) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
        {:ok,
         %{
           public_speech: String.slice(content, 0, 5000),
           private_thought: "",
           tone: "neutral",
           motivation: "unknown",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: nil
         }}
    end
  end

  defp parse_response(response) do
    Logger.warning("Unexpected DeepSeek response shape: #{inspect(response)}")
    {:error, "unexpected_response_shape"}
  end

  # ── Configuration ────────────────────────────────────────────

  defp require_api_key(opts) do
    case api_key(opts) do
      nil -> {:error, "DEEPSEEK_API_KEY not configured"}
      key -> {:ok, key}
    end
  end

  defp api_key(opts) do
    opts[:api_key] || System.get_env("DEEPSEEK_API_KEY")
  end
end
