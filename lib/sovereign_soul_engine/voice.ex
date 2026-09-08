defmodule SovereignSoulEngine.Voice do
  @moduledoc """
  Voice synthesis context for Sovereign Soul Engine.

  Provides high-level APIs for generating speech for character dialogue,
  associating voices with characters, and broadcasting real-time audio updates.
  """

  alias SovereignSoulEngine.Voice.ElevenLabs
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Scenes.SceneMessage

  require Logger

  @doc """
  Checks if voice synthesis is configured and ready.
  """
  defdelegate configured?, to: ElevenLabs

  @doc """
  Lists available voices from ElevenLabs.
  """
  defdelegate list_voices, to: ElevenLabs

  @doc """
  Gets account subscription details and character limits.
  """
  defdelegate get_subscription, to: ElevenLabs

  @doc """
  Generates speech for a given `SceneMessage` asynchronously, attaches
  the audio URL to the message's metadata, and broadcasts the update.
  """
  @spec speak_message_async(SceneMessage.t(), Character.t() | nil) :: Task.t()
  def speak_message_async(message, character) do
    Task.start(fn ->
      speak_message(message, character)
    end)
  end

  @doc """
  Generates speech for a `SceneMessage` synchronously.
  """
  @spec speak_message(SceneMessage.t(), Character.t() | nil) ::
          {:ok, SceneMessage.t()} | {:error, any()}
  def speak_message(%SceneMessage{} = message, character) do
    if configured?() and is_binary(message.content) and String.trim(message.content) != "" do
      voice_id = resolve_voice_id(character)

      opts = [
        voice_id: voice_id,
        filename: "msg_#{message.id}"
      ]

      case ElevenLabs.generate_speech(message.content, opts) do
        {:ok, %{audio_url: audio_url}} ->
          current_meta = message.metadata || %{}

          updated_meta =
            Map.merge(current_meta, %{
              "audio_url" => audio_url,
              "voice_id" => voice_id,
              "voice_status" => "ready"
            })

          case Scenes.update_message(message, %{metadata: updated_meta}) do
            {:ok, updated_msg} ->
              # Broadcast that audio is ready to the scene LiveView
              Phoenix.PubSub.broadcast(
                SovereignSoulEngine.PubSub,
                "scene:#{message.scene_id}",
                {:audio_ready, updated_msg}
              )

              {:ok, updated_msg}

            {:error, reason} ->
              Logger.warning("Failed to update message metadata with audio: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          Logger.warning(
            "ElevenLabs speech generation failed for message #{message.id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :not_configured_or_empty}
    end
  end

  # ── Private Helpers ──────────────────────────────────────────

  defp resolve_voice_id(%Character{metadata: metadata}) when is_map(metadata) do
    metadata["voice_id"] || metadata["elevenlabs_voice_id"] || default_voice_id()
  end

  defp resolve_voice_id(_), do: default_voice_id()

  defp default_voice_id, do: "21m00Tcm4TlvDq8ikWAM"
end
