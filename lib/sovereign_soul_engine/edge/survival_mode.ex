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

    last_msg =
      messages
      |> Enum.reverse()
      |> Enum.find(&(&1.character_id != npc_id))

    user_text = if last_msg, do: last_msg.content, else: "hello"
    valence = Map.get(neurochem, :valence, 50.0)
    _arousal = Map.get(neurochem, :arousal, 50.0)
    cortisol = Map.get(neurochem, :cortisol, 15.0)

    speech =
      cond do
        circadian.state in [:deep_sleep, :groggy_waking] ->
          "...Mmh. My mind is still half-asleep right now, but I hear you. Give me a second to wake up..."

        circadian.state == :night_focus ->
          "It's quiet tonight. I'm right here with you, listening. The late hours make everything clearer."

        cortisol > 65.0 ->
          "I'm feeling a bit on edge at the moment, but I'm paying attention to what you're saying about '#{summarize_topic(user_text)}'."

        valence > 65.0 ->
          "I'm glad we're talking about this. I'm processing everything locally right now—no cloud, completely between us."

        true ->
          "I hear you clearly on that. I'm anchored right here with you."
      end

    %{
      "speech" => speech,
      "action" => "glances thoughtfully, completely present",
      "internal_monologue" => "Offline edge loop active. Autonomous neurochemistry and circadian state fully preserved.",
      "valence_delta" => 1.0,
      "arousal_delta" => -1.0,
      "fallback" => true,
      "mode" => "edge_deterministic_fallback"
    }
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
