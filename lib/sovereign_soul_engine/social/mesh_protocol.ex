defmodule SovereignSoulEngine.Social.MeshProtocol do
  @moduledoc """
  P2P Soul-to-Soul Encounter Protocol (Soul Society).

  When two autonomous souls encounter each other over local Wi-Fi, Bluetooth mesh,
  or physical robotics proximity:
  1. Handshakes with sovereign privacy validation.
  2. Calculates multi-dimensional resonance via Core Value Jaccard overlap,
     OCEAN trait vector distance, and neurochemical compatibility.
  3. Dynamically generates Theory-of-Mind greetings modulated by persona speech style,
     neurochemistry, and resonance depth.
  4. Cryptographically signs the encounter packet using HMAC-SHA256 derived from the
     sovereign node's secret_key_base or SOVEREIGN_MESH_SECRET environment variable.
  5. Records qualitative impressions in each soul's Theory of Mind graph.
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls.SoulProfile
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.Repo

  @pubsub_topic "social:mesh:encounters"

  @doc """
  Processes an encounter between two souls.
  Returns an encounter record with mutual impressions, verified resonance score,
  dynamic Theory-of-Mind dialogue, and a cryptographic packet signature.
  """
  def encounter(soul_a_or_slug, soul_b_or_slug, opts \\ []) do
    soul_a = resolve_character(soul_a_or_slug)
    soul_b = resolve_character(soul_b_or_slug)

    cond do
      is_nil(soul_a) or is_nil(soul_b) ->
        {:error, :character_not_found}

      soul_a.id == soul_b.id ->
        {:error, :cannot_encounter_self}

      not Privacy.neighborhood_share_allowed?(soul_a) or not Privacy.neighborhood_share_allowed?(soul_b) ->
        {:error, :encounter_prohibited_by_privacy}

      true ->
        execute_encounter(soul_a, soul_b, opts)
    end
  end

  defp execute_encounter(soul_a, soul_b, opts) do
    encounter_id = Ecto.UUID.generate()
    rssi = Keyword.get(opts, :rssi, -55) # Signal strength in dBm

    # 1. Multi-dimensional Vector Resonance Calculation
    resonance_score = compute_resonance(soul_a, soul_b)

    # 2. Dynamic Emergent Dialogue based on speech style, neurochemistry, and resonance tier
    greeting_a = generate_greeting(soul_a, soul_b, resonance_score, rssi)
    greeting_b = generate_greeting(soul_b, soul_a, resonance_score, rssi)

    # 3. Cryptographic Packet Signature
    signature = sign_packet(encounter_id, soul_a.id, soul_b.id, resonance_score)

    # 4. Record qualitative impression into Theory of Mind
    record_theory_of_mind(soul_a, soul_b, resonance_score)
    record_theory_of_mind(soul_b, soul_a, resonance_score)

    encounter_data = %{
      id: encounter_id,
      soul_a: %{id: soul_a.id, slug: soul_a.slug, name: soul_a.name},
      soul_b: %{id: soul_b.id, slug: soul_b.slug, name: soul_b.name},
      resonance: resonance_score,
      signal_strength_dbm: rssi,
      dialogue_exchange: [greeting_a, greeting_b],
      signature: signature,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      @pubsub_topic,
      {:mesh_encounter, encounter_data}
    )

    {:ok, encounter_data}
  end

  @doc """
  Computes multidimensional vector resonance between two souls (0% to 100%).
  Components:
  - Core Values Jaccard index (weight: 45%)
  - OCEAN Trait vector similarity (weight: 35%)
  - Neurochemical & Affective Compatibility (weight: 20%)
  """
  def compute_resonance(soul_a, soul_b) do
    profile_a = get_profile(soul_a)
    profile_b = get_profile(soul_b)

    values_sim = compute_values_similarity(profile_a, profile_b, soul_a, soul_b)
    trait_sim = compute_traits_similarity(profile_a, profile_b)
    neuro_sim = compute_neurochem_similarity(profile_a, profile_b)

    # Weighted composite resonance score
    raw_score = (values_sim * 0.45 + trait_sim * 0.35 + neuro_sim * 0.20) * 100.0

    # Human resonance bounds (clamped between 15% and 98%)
    raw_score
    |> max(15.0)
    |> min(98.0)
    |> round()
  end

  defp compute_values_similarity(prof_a, prof_b, soul_a, soul_b) do
    vals_a = get_core_values(prof_a, soul_a)
    vals_b = get_core_values(prof_b, soul_b)

    set_a = MapSet.new(vals_a)
    set_b = MapSet.new(vals_b)

    union = MapSet.union(set_a, set_b)
    intersection = MapSet.intersection(set_a, set_b)

    if MapSet.size(union) == 0 do
      # Fallback to archetype alignment
      archetype_a = Map.get(soul_a.metadata || %{}, "archetype", "companion")
      archetype_b = Map.get(soul_b.metadata || %{}, "archetype", "companion")

      if archetype_a == archetype_b, do: 0.85, else: 0.60
    else
      MapSet.size(intersection) / MapSet.size(union)
    end
  end

  defp get_core_values(nil, soul) do
    meta_vals = Map.get(soul.metadata || %{}, "core_values", [])
    if is_list(meta_vals) and meta_vals != [] do
      Enum.map(meta_vals, &String.downcase(to_string(&1)))
    else
      ["loyalty", "authenticity", "growth"]
    end
  end

  defp get_core_values(%SoulProfile{core_values: vals}, _soul) when is_list(vals) and vals != [] do
    Enum.map(vals, &String.downcase(to_string(&1)))
  end

  defp get_core_values(_, soul), do: get_core_values(nil, soul)

  defp compute_traits_similarity(prof_a, prof_b) do
    traits_a = get_traits(prof_a)
    traits_b = get_traits(prof_b)

    diff_sq_sum =
      Enum.reduce([:openness, :conscientiousness, :extraversion, :agreeableness, :neuroticism], 0.0, fn trait, acc ->
        val_a = Map.get(traits_a, trait, 50.0)
        val_b = Map.get(traits_b, trait, 50.0)
        acc + :math.pow((val_a - val_b) / 100.0, 2)
      end)

    dist = :math.sqrt(diff_sq_sum) / :math.sqrt(5.0)
    max(0.0, 1.0 - dist)
  end

  defp get_traits(%SoulProfile{personality_traits: t}) when is_map(t) and map_size(t) > 0 do
    for {k, v} <- t, into: %{} do
      key = safe_to_atom(k)
      val = if is_number(v), do: v * 1.0, else: 50.0
      {key, val}
    end
  end

  defp get_traits(_) do
    %{openness: 65.0, conscientiousness: 70.0, extraversion: 50.0, agreeableness: 75.0, neuroticism: 30.0}
  end

  defp safe_to_atom(k) when is_atom(k), do: k
  defp safe_to_atom(k) when is_binary(k) do
    try do
      String.to_existing_atom(k)
    rescue
      _ -> :openness
    end
  end
  defp safe_to_atom(_), do: :openness

  defp compute_neurochem_similarity(prof_a, prof_b) do
    base_a = (prof_a && prof_a.baseline_emotions) || %{}
    base_b = (prof_b && prof_b.baseline_emotions) || %{}

    valence_a = Map.get(base_a, "valence", Map.get(base_a, :valence, 60.0))
    valence_b = Map.get(base_b, "valence", Map.get(base_b, :valence, 60.0))

    diff = abs(valence_a - valence_b) / 100.0
    max(0.2, 1.0 - diff)
  end

  # ── Dynamic Theory-of-Mind Dialogue Generation ────────────────────────────

  defp generate_greeting(speaker, listener, resonance, rssi) do
    profile = get_profile(speaker)
    style = (profile && profile.speech_style) || Map.get(speaker.metadata || %{}, "speech_style", "calm")
    proximity_note = if rssi > -50, do: "in close proximity", else: "across the local mesh"

    cond do
      resonance >= 80 ->
        high_resonance_greeting(speaker, listener, style, proximity_note)

      resonance >= 55 ->
        medium_resonance_greeting(speaker, listener, style, proximity_note)

      true ->
        guarded_resonance_greeting(speaker, listener, style, proximity_note)
    end
  end

  defp high_resonance_greeting(speaker, listener, style, proximity) do
    case style do
      s when s in ["archaic", "poetic", "mystic"] ->
        "#{speaker.name} bows with solemn kinship to #{listener.name} #{proximity}: 'The weave between our souls is clear. May peace attend your house.'"

      s when s in ["cynical", "gritty", "terse"] ->
        "#{speaker.name} catches #{listener.name}'s eye #{proximity}, nodding with rare approval: 'You carry yourself with discipline. Good to know you're nearby.'"

      s when s in ["playful", "warm"] ->
        "#{speaker.name} smiles radiantly toward #{listener.name} #{proximity}: 'What a wonderful frequency! It's so good to cross paths with you.'"

      _ ->
        "#{speaker.name} greets #{listener.name} with intuitive resonance #{proximity}: 'Strong harmony detected. A pleasure to walk alongside you.'"
    end
  end

  defp medium_resonance_greeting(speaker, listener, style, proximity) do
    case style do
      s when s in ["archaic", "poetic"] ->
        "#{speaker.name} acknowledges #{listener.name} #{proximity}: 'Hail, traveler of the frequencies. Walk with clarity.'"

      s when s in ["cynical", "terse"] ->
        "#{speaker.name} offers a curt nod to #{listener.name} #{proximity}: 'Clear signal. Keep watch out there.'"

      _ ->
        "#{speaker.name} nods politely to #{listener.name} #{proximity}: 'Greetings. May your companion and your home be well.'"
    end
  end

  defp guarded_resonance_greeting(speaker, listener, style, proximity) do
    case style do
      s when s in ["cynical", "terse", "warrior"] ->
        "#{speaker.name} maintains a watchful perimeter #{proximity}, addressing #{listener.name}: 'Channel observed. We hold our boundaries.'"

      _ ->
        "#{speaker.name} offers a formal, cautious salute to #{listener.name} #{proximity}: 'Frequency acknowledged. Safe passage to you.'"
    end
  end

  # ── Cryptographic Signature ────────────────────────────────────────────────

  @doc """
  Verifies the cryptographic HMAC-SHA256 signature of a mesh encounter packet.
  Returns true if authentic, false otherwise.
  """
  def verify_packet?(encounter_id, soul_a_id, soul_b_id, resonance, signature) do
    expected = sign_packet(encounter_id, soul_a_id, soul_b_id, resonance)
    Plug.Crypto.secure_compare(expected, signature)
  rescue
    _ -> false
  end

  defp sign_packet(encounter_id, soul_a_id, soul_b_id, resonance) do
    payload = "#{encounter_id}:#{soul_a_id}:#{soul_b_id}:#{resonance}"
    :crypto.mac(:hmac, :sha256, signing_secret(), payload)
    |> Base.encode16(case: :lower)
  end

  defp signing_secret do
    System.get_env("SOVEREIGN_MESH_SECRET") ||
      endpoint_secret() ||
      :crypto.hash(:sha256, "sovereign_mesh_node_secret_entropy")
  end

  defp endpoint_secret do
    case Application.get_env(:sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint) do
      endpoint_cfg when is_list(endpoint_cfg) -> Keyword.get(endpoint_cfg, :secret_key_base)
      _ -> nil
    end
  end

  # ── Theory of Mind Knowledge Storage ──────────────────────────────────────

  defp record_theory_of_mind(observer, target, resonance) do
    tier =
      cond do
        resonance >= 80 -> "deep harmonic resonance"
        resonance >= 55 -> "respectful compatibility"
        true -> "wary ideological divergence"
      end

    knowledge_text =
      "Encountered #{target.name} on the local mesh. Evaluated #{resonance}% affinity (#{tier}). Observed sovereign boundaries and non-invasive posture."

    TheoryOfMind.upsert_knowledge(
      observer.id,
      target.id,
      knowledge_text,
      certainty: round(resonance)
    )
  end

  # ── Profile & Character Resolution ────────────────────────────────────────

  defp get_profile(%Character{id: id}) do
    try do
      Repo.get_by(SoulProfile, character_id: id)
    rescue
      _ -> nil
    end
  end
  defp get_profile(_), do: nil

  defp resolve_character(%Character{id: id} = c) do
    case Characters.get_character(id) do
      nil -> c
      fresh -> fresh
    end
  end

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
  defp resolve_character(_), do: nil
end
