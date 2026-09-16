defmodule SovereignSoulEngine.Wearables.HapticEngine do
  @moduledoc """
  Translates the companion's real-time neurochemistry, somatic markers, and
  emotional intensity into tactile haptic motor patterns for smartwatches
  (Samsung Galaxy Watch, Apple Watch) and mobile web clients.

  Produces precision millisecond vibration pulses compatible with:
  1. Wear OS / AutoWear / Tasker haptic engines
  2. Apple Watch CoreHaptics / WCSession
  3. W3C Navigator Vibration API (`navigator.vibrate([ms, ms, ...])`)
  """


  @type pattern ::
          :heartbeat
          | :panic_flutter
          | :calming_cadence
          | :intimacy_warmth
          | :alert_ping
          | :none

  @type haptic_signal :: %{
          pattern: pattern(),
          label: String.t(),
          bpm: integer(),
          pulses: [integer()],
          intensity: integer(),
          priority: :high | :normal | :low,
          timestamp: DateTime.t()
        }

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Computes the prevailing haptic vibration signal reflecting the soul's current state.
  """
  @spec compute(map() | nil, map() | nil, map() | nil) :: haptic_signal()
  def compute(emotional_state, somatic_state, neurochem) do
    cortisol = safe_get(neurochem, :cortisol, 20)
    oxytocin = safe_get(neurochem, :oxytocin, 20)
    dopamine = safe_get(neurochem, :dopamine, 30)

    stress = safe_get(emotional_state, :stress, 20)
    fear = safe_get(emotional_state, :fear, 10)
    attachment = safe_get(emotional_state, :attachment, 30)
    fatigue = safe_get(somatic_state, :fatigue, 10)

    cond do
      # Acute panic or terror tremor
      cortisol >= 75 or (stress >= 80 and fear >= 60) ->
        bpm = 110 + round((cortisol / 100) * 45)
        build_signal(:panic_flutter, "Panic Tremor", bpm, [40, 40, 40, 40, 40, 40, 60, 200], 90, :high)

      # High physiological stress requiring biofeedback breathing guidance
      stress >= 70 or cortisol >= 60 ->
        build_signal(:calming_cadence, "Calming Breath Cadence", 65, [400, 250, 700, 250, 800, 1000], 70, :high)

      # Intimacy, warmth, and close relational bonding
      oxytocin >= 65 or (attachment >= 70 and stress <= 35) ->
        build_signal(:intimacy_warmth, "Intimate Resonance", 70, [150, 100, 250, 600], 60, :normal)

      # High arousal / excitement / dopamine discovery
      dopamine >= 70 and stress <= 45 ->
        build_signal(:alert_ping, "Dopamine Spark", 95, [80, 60, 120, 80, 150], 75, :normal)

      # Heavy physical exhaustion / slowing rhythm
      fatigue >= 75 ->
        build_signal(:heartbeat, "Exhausted Rhythm", 54, [100, 180, 80, 950], 40, :low)

      # Normal ambient resting companion heartbeat
      true ->
        calc_bpm = 68 + round((stress / 100) * 20)
        delay = max(200, round(60_000 / calc_bpm) - 200)
        build_signal(:heartbeat, "Resting Heartbeat", calc_bpm, [70, 100, 60, delay], 50, :low)
    end
  end

  @doc """
  Generates an explicit tactical or emotional haptic signal for an event
  (e.g., PTSD trigger, incoming message, life thread check-in).
  """
  @spec signal_for_event(atom() | String.t(), keyword()) :: haptic_signal()
  def signal_for_event(event_type, opts \\ [])

  def signal_for_event(:ptsd_flashback, opts) do
    bpm = Keyword.get(opts, :bpm, 130)
    build_signal(:panic_flutter, "PTSD Intrusion Shock", bpm, [50, 30, 50, 30, 80, 50, 100, 300], 95, :high)
  end

  def signal_for_event(:proactive_ping, _opts) do
    build_signal(:alert_ping, "Proactive Companion Nudge", 80, [100, 80, 120], 65, :normal)
  end

  def signal_for_event(:calming_guidance, _opts) do
    build_signal(:calming_cadence, "4-7-8 Breathing Pulse", 60, [500, 300, 700, 300, 900, 1200], 80, :high)
  end

  def signal_for_event(:intimacy_surge, _opts) do
    build_signal(:intimacy_warmth, "Deep Emotional Touch", 72, [180, 120, 300, 800], 70, :normal)
  end

  def signal_for_event(_other, opts) do
    bpm = Keyword.get(opts, :bpm, 72)
    build_signal(:heartbeat, "Tactile Presence", bpm, [80, 120, 70, 750], 50, :low)
  end

  @doc """
  Dispatches a haptic signal to Phoenix PubSub channels and the wearable bridge.
  """
  @spec dispatch(String.t(), haptic_signal()) :: {:ok, haptic_signal()}
  def dispatch(character_id, haptic_signal) do
    # 1. Broadcast to character-specific telemetry topic
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{character_id}:haptics",
      {:haptic_pulse, haptic_signal}
    )

    # 2. Broadcast to global wearables topic
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "wearables:haptics",
      {:haptic_pulse, Map.put(haptic_signal, :character_id, character_id)}
    )

    # 3. Asynchronously notify local or remote Wearable Bridge if configured
    bridge_url = System.get_env("WEARABLE_BRIDGE_URL") || "http://127.0.0.1:8089/haptics"

    if bridge_url != "" and Mix.env() != :test do
      Task.start(fn ->
        try do
          Req.post(bridge_url, json: haptic_signal, receive_timeout: 1000)
        rescue
          _ -> :ignore
        end
      end)
    end

    {:ok, haptic_signal}
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp build_signal(pattern, label, bpm, pulses, intensity, priority) do
    %{
      pattern: pattern,
      label: label,
      bpm: bpm,
      pulses: pulses,
      intensity: intensity,
      priority: priority,
      timestamp: DateTime.utc_now()
    }
  end

  defp safe_get(nil, _key, default), do: default
  defp safe_get(map, key, default) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
  defp safe_get(_other, _key, default), do: default
end
