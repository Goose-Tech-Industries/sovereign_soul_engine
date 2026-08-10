defmodule SovereignSoulEngine.LLM.GeminiProvider do
  @moduledoc """
  Google (Gemini) LLM provider.

  Uses the Gemini generateContent API.
  Requires the `GEMINI_API_KEY` environment variable.
  """

  @behaviour SovereignSoulEngine.LLM.Provider

  require Logger

  @default_model "gemini-2.0-flash"

  @impl true
  def provider_name, do: "gemini"

  @impl true
  def health do
    if api_key([]) do
      {:ok, %{status: "configured", model: @default_model}}
    else
      {:error, "GEMINI_API_KEY not configured"}
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
    model = input[:model] || input["model"] || @default_model

    contents = build_contents(messages, system)

    body = %{
      contents: contents,
      generationConfig: %{
        maxOutputTokens: max_tokens,
        response_mime_type: "application/json"
      }
    }

    {:ok, {model, body}}
  end

  defp build_request_body(_input) do
    {:error, "missing required :messages key in input"}
  end

  defp build_contents(messages, nil) when is_list(messages) do
    Enum.map(messages, fn msg ->
      role = if is_map(msg), do: msg[:role] || msg["role"] || "user", else: "user"
      content = if is_map(msg), do: msg[:content] || msg["content"] || "", else: ""

      %{
        role: role_for_gemini(role),
        parts: [%{text: content}]
      }
    end)
  end

  defp build_contents(messages, system) when is_list(messages) do
    system_part = %{
      role: "user",
      parts: [%{text: "# System instruction:\n#{system}"}]
    }

    system_ack = %{
      role: "model",
      parts: [%{text: "Understood. I will follow the system instructions."}]
    }

    user_messages =
      Enum.map(messages, fn msg ->
        role = if is_map(msg), do: msg[:role] || msg["role"] || "user", else: "user"
        content = if is_map(msg), do: msg[:content] || msg["content"] || "", else: ""

        %{
          role: role_for_gemini(role),
          parts: [%{text: content}]
        }
      end)

    [system_part, system_ack | user_messages]
  end

  defp role_for_gemini("assistant"), do: "model"
  defp role_for_gemini("user"), do: "user"
  defp role_for_gemini("system"), do: "user"
  defp role_for_gemini(_), do: "user"

  # ── HTTP Request ─────────────────────────────────────────────

  defp send_request(api_key, {model, body}) do
    url =
      "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}"

    headers = [
      {"content-type", "application/json"}
    ]

    case Req.post(url, json: body, headers: headers, max_retries: 1, receive_timeout: 25_000) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: response_body}} ->
        Logger.warning("Gemini API returned status #{status}: #{inspect(response_body)}")
        {:error, "gemini_http_#{status}"}

      {:error, %{reason: reason}} ->
        Logger.warning("Gemini API request failed: #{inspect(reason)}")
        {:error, "gemini_request_failed: #{inspect(reason)}"}
    end
  end

  # ── Response Parsing ─────────────────────────────────────────

  defp parse_response(%{"candidates" => [%{"content" => %{"parts" => parts}} | _]}) do
    text =
      parts
      |> Enum.map_join("\n", fn part -> part["text"] || "" end)
      |> String.trim()

    case Jason.decode(text) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _} ->
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
  end

  defp parse_response(%{"candidates" => [candidate | _]}) do
    text = candidate |> inspect()

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

  defp parse_response(response) do
    Logger.warning("Unexpected Gemini response shape: #{inspect(response)}")
    {:error, "unexpected_response_shape"}
  end

  # ── Configuration ────────────────────────────────────────────

  defp require_api_key(opts) do
    case api_key(opts) do
      nil -> {:error, "GEMINI_API_KEY not configured"}
      key -> {:ok, key}
    end
  end

  defp api_key(opts) do
    opts[:api_key] || System.get_env("GEMINI_API_KEY")
  end
end
