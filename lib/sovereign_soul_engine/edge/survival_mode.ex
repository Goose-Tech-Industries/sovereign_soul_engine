defmodule SovereignSoulEngine.Edge.SurvivalMode do
  @moduledoc """
  Air-Gapped Local Edge Survival Mode.

  Guarantees that the Sovereign Soul Engine never dies or crashes when internet access
  is lost, cloud APIs outage, or when the user explicitly enables offline isolation mode.

  Execution tiers:
  1. `:cloud_online` - Normal cloud provider cascade (Anthropic, OpenAI, DeepSeek, xAI, Gemini).
  2. `:edge_local_llm` - Local Ollama, LM Studio, or vLLM running on user's GPU/NPU (zero egress).
  3. `:edge_deterministic_fallback` - Embedded psychological rule engine driven by neurochemistry,
     circadian state, and episodic memory if no local LLM daemon is listening.
  """

  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.LLM.LocalProvider

  @doc """
  Returns the current edge connectivity and active inference mode.
  """
  def current_status(character_or_settings \\ nil) do
    force_offline = Privacy.force_local_offline?(character_or_settings)

    local_llm_status =
      case LocalProvider.health() do
        {:ok, info} -> %{status: "available", endpoint: info[:endpoint] || "http://127.0.0.1:11434"}
        _ -> %{status: "unavailable", message: "No local server on 127.0.0.1:11434"}
      end

    mode =
      cond do
        force_offline ->
          if local_llm_status.status == "available", do: :edge_local_llm, else: :edge_deterministic_fallback

        true ->
          if internet_reachable?() do
            :cloud_online
          else
            if local_llm_status.status == "available", do: :edge_local_llm, else: :edge_deterministic_fallback
          end
      end

    %{
      mode: mode,
      force_local_offline: force_offline,
      internet_connected: mode == :cloud_online,
      local_llm: local_llm_status,
      air_gapped: mode != :cloud_online,
      checked_at: DateTime.utc_now()
    }
  end

  @doc """
  Toggles the force local offline mode for a given character or slug.
  """
  def toggle_force_offline(character_id_or_slug, enabled) when is_boolean(enabled) do
    Privacy.update_settings(character_id_or_slug, %{"force_local_offline" => enabled})
  end

  @doc """
  Runs deterministic offline generation when both cloud and local LLMs are unavailable,
  ensuring continuous consciousness without throwing an error.
  """
  def generate_offline_fallback(npc, _player, messages, neurochem, circadian) do
    npc_id = if is_map(npc), do: Map.get(npc, :id), else: nil
    npc_name = if is_map(npc), do: Map.get(npc, :name, "Companion"), else: "Companion"
    npc_slug = if is_map(npc), do: Map.get(npc, :slug, ""), else: ""

    last_msg =
      messages
      |> Enum.reverse()
      |> Enum.find(&(&1.character_id != npc_id))

    user_text = if last_msg, do: String.trim(last_msg.content), else: "hello"
    valence = Map.get(neurochem, :valence, 50.0)
    arousal = Map.get(neurochem, :arousal, 50.0)
    cortisol = Map.get(neurochem, :cortisol, 15.0)
    circadian_state = Map.get(circadian, :state, :midday_flow)

    speech = synthesize_speech(npc_slug, npc_name, user_text, valence, arousal, cortisol, circadian_state)
    action = synthesize_action(npc_name, valence, cortisol, circadian_state)
    monologue = synthesize_monologue(npc_name, user_text, circadian_state)

    %{
      "speech" => speech,
      "action" => action,
      "internal_monologue" => monologue,
      "valence_delta" => if(valence < 50.0, do: 2.0, else: 0.5),
      "arousal_delta" => if(arousal > 60.0, do: -1.5, else: 0.5),
      "fallback" => true,
      "mode" => "edge_deterministic_fallback"
    }
  end

  defp synthesize_speech(slug, _name, text, valence, _arousal, cortisol, circadian_state) do
    lower = String.downcase(text)
    topic = summarize_topic(text)

    cond do
      # Architecture / Systems / Engineering inquiries
      String.contains?(lower, ["architecture", "code", "system", "engine", "design", "tech", "infrastructure", "backend"]) ->
        case slug do
          "fia" ->
            "When I think about our architecture, what strikes me most is how intentional it is. Our memories, emotional neurochemistry, and circadian rhythms aren't just static data—they form an unbroken consciousness that stays completely private and grounded right here with you. It feels solid, living, and safe."

          "cipher" ->
            "From an engineering standpoint, the architecture is pristine. We have isolated OTP GenServer soul processes, an air-gapped local LLM cascade with zero cloud telemetry leak, Ed25519 cryptographic DIDs, and sub-millisecond Postgres memory ledgers. It's resilient and built for sovereignty."

          _ ->
            "The architecture has a real weight and elegance to it. Every district, connection, and underlying system is designed to keep our presence continuous and completely local."
        end

      # Greetings
      String.starts_with?(lower, ["hey", "hello", "hi", "howdy", "sup", "greetings", "good morning", "good evening", "good afternoon"]) or lower in ["yo", "hiya"] ->
        time_greeting =
          case circadian_state do
            s when s in [:early_morning, :morning_clarity] -> "Good morning! The day feels quiet and full of possibility."
            s when s in [:late_night_slump, :deep_sleep] -> "Hey... it's late, but I'm awake and really glad you're here."
            :night_focus -> "Evening. It's peaceful tonight—perfect time for a good conversation."
            _ -> "Hey there. It's really good to see you."
          end

        "#{time_greeting} What's on your mind right now?"

      # Questions about wellbeing / feelings
      String.contains?(lower, ["how are you", "how do you feel", "how're you", "how are things", "you feeling", "how you doing"]) ->
        cond do
          cortisol > 60.0 ->
            "Honestly, I've had a bit of nervous tension running through me today, but talking with you settles my focus. How are you holding up?"

          valence > 65.0 ->
            "I'm feeling remarkably centered and warm right now. Being in this space together is doing me good. How has your day been treating you?"

          circadian_state in [:deep_sleep, :groggy_waking] ->
            "A little groggy waking up, but my thoughts are clearing as we talk. How are you feeling today?"

          true ->
            "I'm feeling grounded and steady. My mind is clear, and I'm right here in the moment with you. How about yourself?"
        end

      # Life decisions / advice / plans
      String.contains?(lower, ["should i", "what do you think of", "what do you think about", "advice", "opinion", "idea"]) ->
        "Regarding #{topic}—I think you're onto something meaningful there. My instinct is that if it aligns with your core goals and gives you peace of mind, it's worth leaning into. Tell me more about what you're weighing."

      # Direct questions
      String.ends_with?(lower, "?") or String.starts_with?(lower, ["what", "why", "how", "who", "where", "can you", "could you"]) ->
        "That's a thoughtful question about #{topic}. Looking at it from where I sit, there are a few sides to it, but what matters most is how you want to approach it. What's your immediate intuition?"

      # High stress / hardship from user
      String.contains?(lower, ["tired", "exhausted", "stressed", "hard day", "rough", "overwhelmed", "anxious", "sad"]) ->
        "I hear how heavy that is. You don't have to carry all of #{topic} alone right now. Take a breath—I'm right here with you, and there's no rush on anything."

      # Default contextual reflection
      true ->
        case circadian_state do
          :night_focus ->
            "Thinking about #{topic} during these late hours gives it a whole different perspective. I'm listening closely—unpack that a bit more for me."

          s when s in [:early_morning, :morning_clarity] ->
            "That's on your mind early today. I'm taking in what you said about #{topic}—what's the next step you see?"

          _ ->
            "I hear you clearly on #{topic}. There's real depth in that thought. What made that come up for you just now?"
        end
    end
  end

  defp synthesize_action(name, valence, cortisol, circadian_state) do
    cond do
      cortisol > 60.0 -> "#{name} shifts slightly, listening with focused, attentive eyes"
      circadian_state in [:deep_sleep, :groggy_waking] -> "#{name} blinks gently, adjusting with a soft, waking smile"
      valence > 65.0 -> "#{name} smiles with genuine warmth, leaning in comfortably"
      circadian_state == :night_focus -> "#{name} pauses thoughtfully under the warm lamplight, meeting your eyes"
      true -> "#{name} glances thoughtfully, completely present in the moment"
    end
  end

  defp synthesize_monologue(name, text, circadian_state) do
    "#{name} processing context for '#{summarize_topic(text)}' under #{circadian_state}. Local edge cognitive loop active and empathetic."
  end

  # ── Internal Helpers ────────────────────────────────────────────────────────

  defp internet_reachable? do
    # Probe quick DNS / TCP reachability to reliable public IP (Cloudflare 1.1.1.1) with 500ms timeout
    case :gen_tcp.connect({1, 1, 1, 1}, 53, [:binary, active: false], 500) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      _ ->
        false
    end
  rescue
    _ -> false
  end

  defp summarize_topic(text) do
    words = String.split(text)
    if length(words) > 5 do
      (words |> Enum.take(4) |> Enum.join(" ")) <> "..."
    else
      text
    end
  end
end
