defmodule SovereignSoulEngine.Voice.LocalTTS do
  @moduledoc """
  Local zero-cost neural text-to-speech engine using edge-tts.
  Generates crisp natural dialogue MP3s without API keys, subscriptions,
  or GPU VRAM overhead.
  """

  require Logger

  @default_voice "en-US-AriaNeural"

  @character_voices %{
    "maya" => "en-US-JennyNeural",
    "ravina" => "en-GB-LibbyNeural",
    "valeria" => "en-US-AriaNeural",
    "cyra" => "en-US-AvaNeural",
    "vael" => "en-US-ChristopherNeural",
    "goose" => "en-US-GuyNeural",
    "sixteen" => "en-US-JennyNeural",
    "georgina" => "en-GB-SoniaNeural"
  }

  @doc """
  Checks if edge-tts CLI is available on the system.
  """
  @spec available?() :: boolean()
  def available? do
    case System.find_executable("edge-tts") do
      nil ->
        case System.find_executable("edge-tts.exe") do
          nil -> false
          _ -> true
        end

      _ ->
        true
    end
  end

  @doc """
  Generates speech for a given text string and character.
  Saves the MP3 into `priv/static/audio/souls/` and returns the public URL.
  """
  @spec generate_speech(String.t(), keyword()) ::
          {:ok, %{audio_url: String.t(), file_path: String.t(), bytes: non_neg_integer()}}
          | {:error, any()}
  def generate_speech(text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      {:error, :empty_text}
    else
      voice = opts[:voice] || resolve_voice(opts[:character])
      filename = (opts[:filename] || Ecto.UUID.generate()) <> ".mp3"

      static_dir = Path.join([:code.priv_dir(:sovereign_soul_engine), "static", "audio", "souls"])
      File.mkdir_p!(static_dir)
      file_path = Path.join(static_dir, filename)

      # Clean text of markdown quotes, actions, or bracketed thoughts before speaking
      clean_spoken_text = sanitize_for_speech(trimmed)

      cmd =
        System.find_executable("edge-tts") || System.find_executable("edge-tts.exe") || "edge-tts"

      args = ["--voice", voice, "--text", clean_spoken_text, "--write-media", file_path]

      case System.cmd(cmd, args, stderr_to_stdout: true) do
        {_output, 0} ->
          if File.exists?(file_path) do
            bytes = File.stat!(file_path).size
            audio_url = "/sse/audio/souls/#{filename}"
            {:ok, %{audio_url: audio_url, file_path: file_path, bytes: bytes}}
          else
            {:error, :file_not_written}
          end

        {output, exit_code} ->
          Logger.warning("edge-tts failed (exit #{exit_code}): #{output}")
          {:error, {:edge_tts_failed, exit_code, output}}
      end
    end
  rescue
    e ->
      Logger.warning("LocalTTS exception: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  @doc """
  Resolves the appropriate neural voice for a character.
  """
  def resolve_voice(nil), do: @default_voice

  def resolve_voice(%{slug: slug}) when is_binary(slug) do
    Map.get(@character_voices, String.downcase(slug), @default_voice)
  end

  def resolve_voice(slug) when is_binary(slug) do
    Map.get(@character_voices, String.downcase(slug), @default_voice)
  end

  def resolve_voice(_), do: @default_voice

  # Removes narrator asterisks (*smiles*), stage directions, and JSON leftovers
  defp sanitize_for_speech(text) do
    text
    |> String.replace(~r/\*[^*]+\*/, "")
    |> String.replace(~r/\([^\)]+\)/, "")
    |> String.replace(~r/\{[^}]+\}/, "")
    |> String.trim()
  end
end
