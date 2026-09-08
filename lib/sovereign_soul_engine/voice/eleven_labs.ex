defmodule SovereignSoulEngine.Voice.ElevenLabs do
  @moduledoc """
  ElevenLabs Text-to-Speech client for Sovereign Soul Engine.

  Supports:
  - Generating spoken audio from NPC public speech
  - Listing available stock, custom, and cloned voices
  - Checking account usage and subscription tier
  - Fast response using the `eleven_flash_v2_5` low-latency model
  """

  require Logger

  @base_url "https://api.elevenlabs.io/v1"
  @default_model "eleven_flash_v2_5"
  # Default fallback voice: "Rachel" (calm, clear)
  @default_voice_id "21m00Tcm4TlvDq8ikWAM"

  @doc """
  Checks if ElevenLabs is configured with an API key.
  """
  @spec configured?(keyword()) :: boolean()
  def configured?(opts \\ []) do
    case get_api_key(opts) do
      key when is_binary(key) and byte_size(key) > 0 -> true
      _ -> false
    end
  end

  @doc """
  Generates speech audio from text and saves it as an MP3 file.

  ## Options:
    - `:voice_id` - ElevenLabs voice ID (defaults to Rachel)
    - `:model_id` - Model ID (defaults to "eleven_flash_v2_5")
    - `:filename` - Custom filename (without extension, defaults to UUID)
    - `:voice_settings` - Map of stability, similarity_boost, etc.
    - `:api_key` - Explicit API key override

  Returns `{:ok, %{audio_url: url, file_path: path, bytes: size}}` or `{:error, reason}`.
  """
  @spec generate_speech(String.t(), keyword()) ::
          {:ok, %{audio_url: String.t(), file_path: String.t(), bytes: non_neg_integer()}}
          | {:error, any()}
  def generate_speech(text, opts \\ []) when is_binary(text) do
    with {:ok, api_key} <- require_api_key(opts),
         {:ok, trimmed_text} <- validate_text(text) do
      voice_id = opts[:voice_id] || @default_voice_id
      model_id = opts[:model_id] || @default_model

      url = "#{@base_url}/text-to-speech/#{voice_id}"

      payload = %{
        text: trimmed_text,
        model_id: model_id,
        voice_settings:
          opts[:voice_settings] ||
            %{
              stability: 0.5,
              similarity_boost: 0.75
            }
      }

      headers = [
        {"xi-api-key", api_key},
        {"content-type", "application/json"},
        {"accept", "audio/mpeg"}
      ]

      case Req.post(url, json: payload, headers: headers, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: audio_binary}} when is_binary(audio_binary) ->
          save_audio_file(audio_binary, opts)

        {:ok, %{status: status, body: body}} ->
          Logger.warning("ElevenLabs TTS error #{status}: #{inspect(body)}")
          {:error, "elevenlabs_http_#{status}: #{inspect(body)}"}

        {:error, reason} ->
          Logger.warning("ElevenLabs TTS request failed: #{inspect(reason)}")
          {:error, "request_failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Fetches all voices available to the configured ElevenLabs account.
  """
  @spec list_voices(keyword()) :: {:ok, [map()]} | {:error, any()}
  def list_voices(opts \\ []) do
    with {:ok, api_key} <- require_api_key(opts) do
      url = "#{@base_url}/voices"
      headers = [{"xi-api-key", api_key}]

      case Req.get(url, headers: headers, receive_timeout: 15_000) do
        {:ok, %{status: 200, body: %{"voices" => voices}}} ->
          formatted =
            Enum.map(voices, fn v ->
              %{
                voice_id: v["voice_id"],
                name: v["name"],
                category: v["category"],
                description: v["description"],
                preview_url: v["preview_url"],
                labels: v["labels"] || %{}
              }
            end)

          {:ok, formatted}

        {:ok, %{status: status, body: body}} ->
          {:error, "elevenlabs_http_#{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "request_failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Fetches the user's subscription and character usage info.
  """
  @spec get_subscription(keyword()) :: {:ok, map()} | {:error, any()}
  def get_subscription(opts \\ []) do
    with {:ok, api_key} <- require_api_key(opts) do
      url = "#{@base_url}/user/subscription"
      headers = [{"xi-api-key", api_key}]

      case Req.get(url, headers: headers, receive_timeout: 15_000) do
        {:ok, %{status: 200, body: body}} ->
          {:ok,
           %{
             tier: body["tier"],
             character_count: body["character_count"],
             character_limit: body["character_limit"],
             status: body["status"],
             next_character_count_reset_unix: body["next_character_count_reset_unix"]
           }}

        {:ok, %{status: status, body: body}} ->
          {:error, "elevenlabs_http_#{status}: #{inspect(body)}"}

        {:error, reason} ->
          {:error, "request_failed: #{inspect(reason)}"}
      end
    end
  end

  # ── Private Helpers ──────────────────────────────────────────

  defp save_audio_file(audio_binary, opts) do
    filename = (opts[:filename] || Ecto.UUID.generate()) <> ".mp3"
    static_dir = Path.join([:code.priv_dir(:sovereign_soul_engine), "static", "audio", "souls"])
    File.mkdir_p!(static_dir)

    file_path = Path.join(static_dir, filename)

    case File.write(file_path, audio_binary) do
      :ok ->
        audio_url = "/sse/audio/souls/#{filename}"
        {:ok, %{audio_url: audio_url, file_path: file_path, bytes: byte_size(audio_binary)}}

      {:error, reason} ->
        {:error, "failed_to_write_audio: #{inspect(reason)}"}
    end
  end

  defp validate_text(text) do
    trimmed = String.trim(text)

    if trimmed != "" do
      {:ok, trimmed}
    else
      {:error, :empty_text}
    end
  end

  defp require_api_key(opts) do
    case get_api_key(opts) do
      key when is_binary(key) and byte_size(key) > 0 -> {:ok, key}
      _ -> {:error, "ELEVENLABS_API_KEY not configured"}
    end
  end

  defp get_api_key(opts) do
    case opts[:api_key] do
      key when is_binary(key) and byte_size(key) > 0 ->
        key

      # Explicit `api_key: nil` (or empty string) disables the ambient env/.env
      # lookup so callers — and tests — can deterministically force an
      # "unconfigured" state without touching the environment.
      _ ->
        if Keyword.has_key?(opts, :api_key) do
          nil
        else
          System.get_env("ELEVENLABS_API_KEY") || read_env_file("ELEVENLABS_API_KEY")
        end
    end
  end

  defp read_env_file(key) do
    env_paths = [
      Path.join(File.cwd!(), ".env"),
      Path.join([File.cwd!(), "..", "tew_sidecar", ".env"])
    ]

    Enum.find_value(env_paths, fn path ->
      if File.exists?(path) do
        File.stream!(path)
        |> Enum.find_value(fn line ->
          case String.split(String.trim(line), "=", parts: 2) do
            [^key, val] -> String.trim(val, "\"")
            _ -> nil
          end
        end)
      end
    end)
  end
end
