defmodule SovereignSoulEngine.Voice do
  @moduledoc """
  Voice synthesis context for Sovereign Soul Engine.

  Provides high-level APIs for generating speech for character dialogue,
  associating voices with characters, and broadcasting real-time audio updates.
  """

  alias SovereignSoulEngine.Voice.{ElevenLabs, LocalTTS}
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Scenes.SceneMessage

  require Logger

  @doc """
  Checks if voice synthesis is configured and ready.
  """
  def configured? do
    ElevenLabs.configured?() or LocalTTS.available?()
  end

  @doc """
  Lists available voices from ElevenLabs.
  """
  defdelegate list_voices, to: ElevenLabs

  @doc """
  Gets account subscription details and character limits.
  """
  defdelegate get_subscription, to: ElevenLabs

  alias SovereignSoulEngine.Repo

  @doc """
  Generates speech for a given `SceneMessage` asynchronously under Task.Supervisor,
  attaches the audio URL to the message's metadata, and broadcasts the update.
  """
  @spec speak_message_async(SceneMessage.t(), Character.t() | nil) :: {:ok, pid()} | {:error, any()}
  def speak_message_async(message, character) do
    caller_pid = self()

    task_fn = fn ->
      try_allow_sandbox(caller_pid)
      speak_message(message, character)
    end

    case Process.whereis(SovereignSoulEngine.TaskSupervisor) do
      nil ->
        Task.start(task_fn)

      _supervisor ->
        Task.Supervisor.start_child(SovereignSoulEngine.TaskSupervisor, task_fn)
    end
  end

  @doc """
  Generates speech for a `SceneMessage` synchronously with fresh DB state lookup.
  """
  @spec speak_message(SceneMessage.t(), Character.t() | nil) ::
          {:ok, SceneMessage.t()} | {:error, any()}
  def speak_message(%SceneMessage{} = message, character) do
    if configured?() and is_binary(message.content) and String.trim(message.content) != "" do
      voice_id = resolve_voice_id(character)

      gen_result =
        if ElevenLabs.configured?() do
          ElevenLabs.generate_speech(message.content, voice_id: voice_id, filename: "msg_#{message.id}")
        else
          LocalTTS.generate_speech(message.content, character: character, filename: "msg_#{message.id}")
        end

      case gen_result do
        {:ok, %{audio_url: audio_url}} ->
          update_message_audio_metadata(message, voice_id, audio_url)

        {:error, reason} ->
          Logger.warning(
            "Speech generation failed for message #{message.id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    else
      {:error, :not_configured_or_empty}
    end
  end

  defp update_message_audio_metadata(%SceneMessage{id: id, scene_id: scene_id}, voice_id, audio_url) do
    try do
      fresh_message = Repo.get(SceneMessage, id)

      if fresh_message do
        current_meta = fresh_message.metadata || %{}

        updated_meta =
          Map.merge(current_meta, %{
            "audio_url" => audio_url,
            "voice_id" => voice_id,
            "voice_status" => "ready"
          })

        case Scenes.update_message(fresh_message, %{metadata: updated_meta}) do
          {:ok, updated_msg} ->
            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "scene:#{scene_id}",
              {:audio_ready, updated_msg}
            )

            {:ok, updated_msg}

          {:error, reason} ->
            Logger.warning("Failed to update message metadata with audio: #{inspect(reason)}")
            {:error, reason}
        end
      else
        {:error, :message_not_found}
      end
    rescue
      e in DBConnection.OwnershipError ->
        Logger.debug("Skipping message metadata update in sandbox: #{inspect(e)}")
        {:ok, %SceneMessage{id: id, scene_id: scene_id}}

      e in Ecto.StaleEntryError ->
        Logger.debug("Stale entry on audio metadata update, retrying once: #{inspect(e)}")
        case Repo.get(SceneMessage, id) do
          nil -> {:error, :message_not_found}
          refreshed ->
            current_meta = refreshed.metadata || %{}
            Scenes.update_message(refreshed, %{metadata: Map.put(current_meta, "audio_url", audio_url)})
        end
    end
  end

  defp try_allow_sandbox(caller_pid) do
    if Code.ensure_loaded?(Ecto.Adapters.SQL.Sandbox) do
      try do
        Ecto.Adapters.SQL.Sandbox.allow(SovereignSoulEngine.Repo, caller_pid, self())
      rescue
        _ -> :ok
      end
    end
  end

  # ── Private Helpers ──────────────────────────────────────────

  defp resolve_voice_id(%Character{metadata: metadata}) when is_map(metadata) do
    metadata["voice_id"] || metadata["elevenlabs_voice_id"] || default_voice_id()
  end

  defp resolve_voice_id(_), do: default_voice_id()

  defp default_voice_id, do: "21m00Tcm4TlvDq8ikWAM"
end
