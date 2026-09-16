defmodule SovereignSoulEngine.Privacy do
  @moduledoc """
  User Privacy, Consent, and Autonomy Governance.

  Provides users with complete sovereignty to selectively disable, pause, or customize
  invasive features, including:
  1. Proactive check-ins (master toggle, stress spikes, morning wakeups, late-night insomnia, quiet hours).
  2. Biometric and smartwatch telemetry ingestion (heart rate, stress, sleep).
  3. Wearable haptic biofeedback (wrist vibrations, heartbeat cadence).
  4. Multimodal smart glasses visual perception (camera capture, face detection).
  5. Smart home ambient lighting synchronization (color shifts, Philips Hue/Home Assistant).
  6. Amazon Alexa voice broadcasts.
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character

  @default_settings %{
    # Autonomous Outreach & Proactive Care
    "proactive_checkins" => true,
    "somatic_stress_checkins" => true,
    "morning_wake_checkins" => true,
    "late_night_checkins" => true,
    "quiet_hours_enabled" => false,
    "quiet_hours_start" => 22,
    "quiet_hours_end" => 8,

    # Wearables & Biometrics
    "biometrics_tracking" => true,
    "haptic_feedback" => true,

    # Multimodal Smart Glasses
    "camera_vision" => true,
    "ambient_audio" => true,

    # Smart Home & IoT Ambient Lighting
    "ambient_lighting" => true,

    # Amazon Alexa Voice Integration
    "alexa_voice" => true
  }

  @doc """
  Returns the system-wide baseline default privacy configuration.
  """
  def default_settings, do: @default_settings

  @doc """
  Retrieves effective privacy settings for a character or user.
  Defaults are merged with any explicit user-defined overrides in character.metadata.
  """
  def get_settings(nil), do: @default_settings

  def get_settings(%Character{metadata: metadata}) do
    user_settings = (metadata && metadata["privacy_settings"]) || %{}
    Map.merge(@default_settings, user_settings)
  end

  def get_settings(character_id_or_slug) when is_binary(character_id_or_slug) do
    character = resolve_character(character_id_or_slug)
    get_settings(character)
  end

  @doc """
  Updates privacy settings for a character and broadcasts the update.
  """
  def update_settings(character_id_or_slug, new_settings) do
    character = resolve_character(character_id_or_slug)

    if character do
      current_settings = get_settings(character)
      merged_settings = Map.merge(current_settings, stringify_keys(new_settings))

      current_metadata = character.metadata || %{}
      updated_metadata = Map.put(current_metadata, "privacy_settings", merged_settings)

      case Characters.update_character(character, %{metadata: updated_metadata}) do
        {:ok, updated_char} ->
          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            "character:#{updated_char.id}:privacy",
            {:privacy_settings_updated, merged_settings}
          )

          {:ok, merged_settings}

        error ->
          error
      end
    else
      {:error, :character_not_found}
    end
  end

  # ── Boundary Check Evaluators ───────────────────────────────────────────────

  @doc """
  Evaluates whether proactive outreach / check-in is permitted for a given event type.
  """
  def checkin_allowed?(character_or_id, event_type \\ :general) do
    settings = get_settings(character_or_id)

    cond do
      # 1. Master kill-switch
      settings["proactive_checkins"] == false ->
        false

      # 2. Quiet hours / Do Not Disturb
      settings["quiet_hours_enabled"] && in_quiet_hours?(settings) ->
        false

      # 3. Specific somatic event toggles
      event_type == :acute_stress && settings["somatic_stress_checkins"] == false ->
        false

      event_type == :morning_waking && settings["morning_wake_checkins"] == false ->
        false

      event_type == :late_night_insomnia && settings["late_night_checkins"] == false ->
        false

      true ->
        true
    end
  end

  @doc """
  Checks if wearable biometric ingestion (HR, stress, sleep) is enabled.
  """
  def biometrics_allowed?(character_or_id) do
    get_settings(character_or_id)["biometrics_tracking"] != false
  end

  @doc """
  Checks if wearable tactile haptic vibrations (heartbeats, calming guidance) are enabled.
  """
  def haptics_allowed?(character_or_id) do
    get_settings(character_or_id)["haptic_feedback"] != false
  end

  @doc """
  Checks if smart glasses camera capture and perception are enabled.
  """
  def vision_allowed?(character_or_id) do
    get_settings(character_or_id)["camera_vision"] != false
  end

  @doc """
  Checks if smart home room lighting color syncing is enabled.
  """
  def ambient_lighting_allowed?(character_or_id) do
    get_settings(character_or_id)["ambient_lighting"] != false
  end

  @doc """
  Checks if Amazon Alexa Echo skill and voice interaction are enabled.
  """
  def alexa_allowed?(character_or_id) do
    get_settings(character_or_id)["alexa_voice"] != false
  end

  # ── Internal Helpers ────────────────────────────────────────────────────────

  defp in_quiet_hours?(settings) do
    current_hour = DateTime.utc_now().hour
    start_hour = parse_hour(settings["quiet_hours_start"], 22)
    end_hour = parse_hour(settings["quiet_hours_end"], 8)

    if start_hour > end_hour do
      # Spans midnight (e.g. 22:00 to 08:00)
      current_hour >= start_hour || current_hour < end_hour
    else
      current_hour >= start_hour && current_hour < end_hour
    end
  end

  defp parse_hour(val, _default) when is_integer(val), do: val
  defp parse_hour(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error ->
        case String.split(val, ":") do
          [h | _] ->
            case Integer.parse(h) do
              {int, _} -> int
              _ -> default
            end
          _ -> default
        end
    end
  end
  defp parse_hour(_, default), do: default

  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Characters.get_character_by_slug(id_or_slug) do
      nil ->
        case Ecto.UUID.cast(id_or_slug) do
          {:ok, uuid} -> Characters.get_character(uuid)
          :error -> nil
        end
      char ->
        char
    end
  end
  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(_), do: nil

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
