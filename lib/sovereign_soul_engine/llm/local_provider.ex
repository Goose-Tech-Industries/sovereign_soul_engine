defmodule SovereignSoulEngine.LLM.LocalProvider do
  @moduledoc """
  Local LLM provider for Ollama, LM Studio, or vLLM running on local GPU.
  Uses the standard OpenAI-compatible `/v1/chat/completions` API.
  Zero API keys required, zero telemetry, zero censorship.
  """

  @behaviour SovereignSoulEngine.LLM.Provider

  @default_url "http://localhost:11434/v1/chat/completions"
  @default_model "llama3.1:8b"

  @impl true
  def provider_name, do: "local"

  @impl true
  def health do
    url = base_url()

    case Req.get("http://localhost:11434/api/tags", receive_timeout: 2000) do
      {:ok, %{status: 200}} ->
        {:ok, %{status: "available", model: model_name(), endpoint: url}}

      _ ->
        {:error, "Local LLM server not reachable on localhost:11434"}
    end
  rescue
    _ -> {:error, "Local LLM server not reachable on localhost:11434"}
  end

  @impl true
  def respond(input, opts \\ []) do
    with {:ok, body} <- build_request_body(input, opts),
         {:ok, response} <- send_request(body, opts),
         {:ok, parsed} <- parse_response(response) do
      {:ok, parsed}
    end
  end

  # ── Request Building ─────────────────────────────────────────

  defp build_request_body(%{messages: messages} = input, opts) do
    system = input[:system] || input["system"]
    max_tokens = input[:max_tokens] || input["max_tokens"] || 4096
    model = Keyword.get(opts, :model, model_name())

    msgs = build_messages(messages, system)

    body = %{
      model: model,
      messages: msgs,
      max_tokens: max_tokens,
      response_format: %{type: "json_object"}
    }

    {:ok, body}
  end

  defp build_request_body(_input, _opts) do
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
      | build_messages(messages, nil)
    ]
  end

  # ── HTTP Communication ──────────────────────────────────────

  defp send_request(body, opts) do
    url = base_url()
    timeout = Keyword.get(opts, :timeout_ms, 60_000)

    case Req.post(url,
           json: body,
           headers: [{"authorization", "Bearer ollama"}],
           receive_timeout: timeout
         ) do
      {:ok, %{status: 200, body: resp_body}} ->
        {:ok, resp_body}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "Local LLM error (HTTP #{status}): #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, "Local LLM connection failed: #{inspect(reason)}"}
    end
  end

  # ── Response Parsing ────────────────────────────────────────

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]} = raw) do
    case Jason.decode(content) do
      {:ok, parsed_json} ->
        {:ok, %{content: parsed_json, raw_response: raw}}

      {:error, _} ->
        {:ok, %{content: %{"public_speech" => content}, raw_response: raw}}
    end
  end

  defp parse_response(response) do
    {:error, "unexpected response format from Local LLM: #{inspect(response)}"}
  end

  defp base_url do
    Application.get_env(:sovereign_soul_engine, :local_llm_url, @default_url)
  end

  defp model_name do
    Application.get_env(:sovereign_soul_engine, :local_llm_model, @default_model)
  end
end
