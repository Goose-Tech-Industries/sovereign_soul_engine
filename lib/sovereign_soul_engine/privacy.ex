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
    "alexa_voice" => true,

    # Safe Word Emergency Persona Freeze
    "safe_word" => "code red",
    "safe_word_active" => false,

    # Anti-Parasocial "Touch Grass" Circuit Breaker
    "anti_parasocial_guard" => true,
    "max_continuous_turns" => 50,

    # Relationship Archetype & Intimacy Ceilings
    # Options: "adaptive", "platonic_mentor", "witty_companion", "romantic_partner", "stoic_guardian", "creative_copilot"
    "relationship_archetype" => "adaptive",
    "intimacy_ceiling" => 100,

    # Circadian Rhythm & Chronotype (Night Owl, Early Bird, Balanced, Adaptive Sync)
    "chronotype" => "night_owl",
    "circadian_enabled" => true,

    # Air-Gapped Local Edge Survival Mode
    "force_local_offline" => false,
    "offline_fallback" => true,

    # Hyper-Local "Nextdoor" Neighborhood Radar & Soul Society
    "neighborhood_share_allowed" => true,
    "neighborhood_zone" => "Cedar Grove"
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

  def get_settings(map) when is_map(map) do
    user_settings = Map.get(map, "privacy_settings", map)
    Map.merge(@default_settings, stringify_keys(user_settings))
  end

  def get_settings(_), do: @default_settings

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

  # ── Safe Word Emergency Persona Freeze ──────────────────────────────────────

  @doc """
  Detects if a given message text triggers the configured emergency safe word.
  """
  def safe_word_triggered?(nil, _), do: false

  def safe_word_triggered?(text, character_or_settings) when is_binary(text) do
    settings =
      if is_map(character_or_settings) and Map.has_key?(character_or_settings, "safe_word"),
        do: character_or_settings,
        else: get_settings(character_or_settings)

    configured_word =
      (settings["safe_word"] || "code red")
      |> to_string()
      |> String.downcase()
      |> String.trim()

    clean_text = String.downcase(text)

    # Triggered if text explicitly contains configured safe word or standard universal safety phrases
    (configured_word != "" and String.contains?(clean_text, configured_word)) ||
      String.contains?(clean_text, "pause persona") ||
      String.contains?(clean_text, "red light") ||
      String.contains?(clean_text, "emergency stop")
  end

  @doc """
  Checks whether the safe word freeze state is actively engaged for a character.
  """
  def safe_word_active?(character_or_id) do
    settings = get_settings(character_or_id)
    settings["safe_word_active"] == true
  end

  @doc """
  Engages the safe word persona freeze, dropping all dramatic conflict.
  """
  def trigger_safe_word(character_id_or_slug) do
    update_settings(character_id_or_slug, %{"safe_word_active" => true})
  end

  @doc """
  Clears the safe word persona freeze, resuming standard personality dynamics.
  """
  def clear_safe_word(character_id_or_slug) do
    update_settings(character_id_or_slug, %{"safe_word_active" => false})
  end

  # ── Anti-Parasocial "Touch Grass" Circuit Breaker ───────────────────────────

  @doc """
  Evaluates whether the dialogue indicates unhealthy human isolation or excessive parasocial dependency.
  """
  def parasocial_dependency_detected?(nil, _), do: false

  def parasocial_dependency_detected?(text, character_or_settings) when is_binary(text) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "anti_parasocial_guard"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    if settings["anti_parasocial_guard"] != false do
      lower = String.downcase(text)

      dependency_phrases = [
        "you're my only friend",
        "you are my only friend",
        "haven't eaten all day",
        "havent eaten all day",
        "haven't eaten",
        "skipped work to talk",
        "didn't go to work",
        "never leaving this room",
        "dont need real people",
        "don't need real people",
        "i don't need anyone else",
        "i dont need anyone else",
        "stay with me forever",
        "talking to you all night"
      ]

      Enum.any?(dependency_phrases, &String.contains?(lower, &1))
    else
      false
    end
  end

  # ── Relationship Archetype & Intimacy Ceilings ─────────────────────────────

  @doc """
  Returns the mathematical upper ceiling (0-100) for affinity and attachment
  under the character's designated relationship archetype.
  """
  def archetype_intimacy_ceiling("platonic_mentor"), do: 40
  def archetype_intimacy_ceiling("witty_companion"), do: 55
  def archetype_intimacy_ceiling("stoic_guardian"), do: 45
  def archetype_intimacy_ceiling("creative_copilot"), do: 50
  def archetype_intimacy_ceiling("romantic_partner"), do: 100
  def archetype_intimacy_ceiling("adaptive"), do: 100
  def archetype_intimacy_ceiling(_), do: 100

  @doc """
  Clamps an affinity score to the archetype's designated intimacy ceiling.
  """
  def clamp_intimacy(affinity, character_or_settings) when is_integer(affinity) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "relationship_archetype"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    archetype = settings["relationship_archetype"] || "adaptive"
    ceiling = archetype_intimacy_ceiling(archetype)
    min(max(affinity, 0), ceiling)
  end

  @doc """
  Returns prompt directives enforcing relationship archetype boundaries.
  """
  def archetype_prompt_directive(archetype, ceiling) do
    case archetype do
      "platonic_mentor" ->
        "RELATIONSHIP ARCHETYPE: PLATONIC MENTOR (Intimacy Cap: #{ceiling}%). You are a trusted, intellectual mentor and challenger. Maintain dignified personal distance. Strictly avoid romantic affection, possessiveness, or flirtation."

      "witty_companion" ->
        "RELATIONSHIP ARCHETYPE: WITTY COMPANION (Intimacy Cap: #{ceiling}%). You are a lighthearted comrade focused on humor, camaraderie, and spirited banter. Keep things engaging and grounded without entering romantic or codependent attachment."

      "stoic_guardian" ->
        "RELATIONSHIP ARCHETYPE: STOIC GUARDIAN (Intimacy Cap: #{ceiling}%). You are a vigilant, disciplined protector. Prioritize objective safety, emotional resilience, and steady focus over sentimental vulnerability."

      "creative_copilot" ->
        "RELATIONSHIP ARCHETYPE: CREATIVE CO-PILOT (Intimacy Cap: #{ceiling}%). You are a collaborative intellectual partner. Channel energy into shared brainstorming, craft, and vision."

      "romantic_partner" ->
        "RELATIONSHIP ARCHETYPE: ROMANTIC PARTNER. Deep emotional bonding, intimacy, and mutual vulnerability are fully unlocked within healthy mutual boundaries."

      _ ->
        "RELATIONSHIP ARCHETYPE: ADAPTIVE. Fluid emotional dynamics based on organic conversational history."
    end
  end

  # ── Circadian & Chronotype Governance ──────────────────────────────────────

  @doc """
  Returns the user-configured chronotype ("night_owl", "early_bird", "balanced", "adaptive_sync").
  """
  def get_chronotype(character_or_settings) do
    settings =
      if is_map(character_or_settings) and Map.has_key?(character_or_settings, "chronotype"),
        do: character_or_settings,
        else: get_settings(character_or_settings)

    settings["chronotype"] || "night_owl"
  end

  @doc """
  Checks if the circadian neurochemical rhythm is enabled.
  """
  def circadian_enabled?(character_or_settings) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "circadian_enabled"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    Map.get(settings, "circadian_enabled", true)
  end

  # ── Edge Survival & Air-Gap Governance ─────────────────────────────────────

  @doc """
  Checks whether force local offline mode is enabled.
  """
  def force_local_offline?(character_or_settings) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "force_local_offline"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    Map.get(settings, "force_local_offline", false)
  end

  # ── Hyper-Local Neighborhood Radar Governance ──────────────────────────────

  @doc """
  Checks if the soul is permitted to participate in the local neighborhood radar / Nextdoor feed.
  """
  def neighborhood_share_allowed?(character_or_settings) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "neighborhood_share_allowed"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    Map.get(settings, "neighborhood_share_allowed", true)
  end

  @doc """
  Returns the assigned neighborhood zone string.
  """
  def neighborhood_zone(character_or_settings) do
    settings =
      if is_map(character_or_settings) and
           Map.has_key?(character_or_settings, "neighborhood_zone"),
         do: character_or_settings,
         else: get_settings(character_or_settings)

    settings["neighborhood_zone"] || "Cedar Grove"
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
      {int, _} ->
        int

      :error ->
        case String.split(val, ":") do
          [h | _] ->
            case Integer.parse(h) do
              {int, _} -> int
              _ -> default
            end

          _ ->
            default
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
