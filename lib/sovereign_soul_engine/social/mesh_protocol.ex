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
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Souls

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

      not Privacy.neighborhood_share_allowed?(soul_a) or
          not Privacy.neighborhood_share_allowed?(soul_b) ->
        {:error, :encounter_prohibited_by_privacy}

      true ->
        execute_encounter(soul_a, soul_b, opts)
    end
  end

  defp execute_encounter(soul_a, soul_b, opts) do
    encounter_id = Ecto.UUID.generate()
    # Signal strength in dBm
    rssi = Keyword.get(opts, :rssi, -55)

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

  @value_clusters %{
    sovereignty: [
      "autonomy",
      "sovereignty",
      "independence",
      "freedom",
      "self-reliance",
      "liberty"
    ],
    truth: [
      "truth",
      "knowledge",
      "history",
      "preservation",
      "archives",
      "mathematical truth",
      "curiosity",
      "accuracy",
      "scholarship",
      "learning"
    ],
    sanctuary: [
      "sanctuary",
      "compassion",
      "empathy",
      "healing",
      "protection",
      "gentleness",
      "peace",
      "mercy",
      "rest",
      "care"
    ],
    craft: [
      "craft",
      "honor the craft",
      "iron",
      "steel",
      "forge",
      "building",
      "honest work",
      "dignity",
      "soil",
      "stone",
      "creation",
      "labor"
    ],
    vigilance: [
      "vigilance",
      "defense",
      "order",
      "guarding",
      "watch",
      "bastion",
      "discipline",
      "sentinel",
      "perimeter",
      "law"
    ],
    shadow: [
      "leverage",
      "ambition",
      "secrets",
      "cunning",
      "wealth",
      "influence",
      "power",
      "survival",
      "pragmatism"
    ],
    community: [
      "fellowship",
      "community",
      "hospitality",
      "friendship",
      "loyalty",
      "music",
      "song",
      "harmony",
      "kinship",
      "bonds"
    ],
    spirit: [
      "celestial",
      "spiritual clarity",
      "stars",
      "destiny",
      "magic",
      "cosmos",
      "faith",
      "ancestors",
      "sacred"
    ]
  }

  @doc """
  Computes multidimensional vector resonance between two souls (15% to 98%).
  Components:
  - Core Values & Philosophical Alignment (weight: 30%)
  - Cumulative Relationship History & Affinity (weight: 35%)
  - OCEAN Trait vector complementarity (weight: 20%)
  - Real-Time Neurochemistry & Emotional State (weight: 15%)
  """
  def compute_resonance(soul_a, soul_b) do
    profile_a = get_profile(soul_a)
    profile_b = get_profile(soul_b)

    values_sim = compute_values_similarity(profile_a, profile_b, soul_a, soul_b)
    {rel_sim, has_rel?} = compute_relationship_affinity(soul_a, soul_b)
    trait_sim = compute_traits_similarity(profile_a, profile_b, soul_a, soul_b)
    neuro_sim = compute_neurochem_similarity(profile_a, profile_b, soul_a, soul_b)

    # Weighted composite resonance score across the entire human spectrum
    raw_score =
      if has_rel? do
        # Existing relationships strongly color resonance
        (rel_sim * 0.55 + values_sim * 0.20 + trait_sim * 0.15 + neuro_sim * 0.10) * 100.0
      else
        # Strangers encounter: worldview values, traits, and current emotional valence
        (values_sim * 0.45 + trait_sim * 0.30 + neuro_sim * 0.25) * 100.0
      end

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

    exact_jaccard =
      if MapSet.size(union) > 0 do
        MapSet.size(intersection) / MapSet.size(union)
      else
        0.0
      end

    clusters_a = map_to_clusters(vals_a)
    clusters_b = map_to_clusters(vals_b)

    cluster_inter = MapSet.intersection(clusters_a, clusters_b)
    cluster_union = MapSet.union(clusters_a, clusters_b)

    cluster_jaccard =
      if MapSet.size(cluster_union) > 0 do
        MapSet.size(cluster_inter) / MapSet.size(cluster_union)
      else
        0.50
      end

    arch_a = (prof_a && prof_a.identity_summary) || (soul_a && soul_a.description) || ""
    arch_b = (prof_b && prof_b.identity_summary) || (soul_b && soul_b.description) || ""
    archetype_synergy = compute_archetype_synergy(arch_a, arch_b)

    cond do
      exact_jaccard > 0.0 ->
        min(1.0, 0.40 * exact_jaccard + 0.40 * cluster_jaccard + 0.20 * archetype_synergy)

      MapSet.size(cluster_inter) > 0 ->
        min(0.92, 0.55 * cluster_jaccard + 0.45 * archetype_synergy)

      true ->
        max(0.15, min(0.48, archetype_synergy * 0.60))
    end
  end

  defp map_to_clusters(vals) do
    Enum.reduce(vals, MapSet.new(), fn val, acc ->
      v_lower = String.downcase(to_string(val))

      matched =
        Enum.find_value(@value_clusters, fn {cluster, keywords} ->
          if Enum.any?(keywords, &String.contains?(v_lower, &1)), do: cluster, else: nil
        end)

      if matched, do: MapSet.put(acc, matched), else: acc
    end)
  end

  defp compute_archetype_synergy(desc_a, desc_b) do
    da = String.downcase(to_string(desc_a))
    db = String.downcase(to_string(desc_b))

    cond do
      (String.contains?(da, "guard") or String.contains?(da, "sentinel") or
         String.contains?(da, "bastion")) and
          (String.contains?(db, "blacksmith") or String.contains?(db, "forge") or
             String.contains?(db, "steel")) ->
        0.82

      (String.contains?(da, "healer") or String.contains?(da, "herbalist") or
         String.contains?(da, "sanctuary")) and
          (String.contains?(db, "gem") or String.contains?(db, "jewel") or
             String.contains?(db, "weaver")) ->
        0.80

      (String.contains?(da, "chronicler") or String.contains?(da, "archivist") or
         String.contains?(da, "scholar")) and
          (String.contains?(db, "cryptographer") or String.contains?(db, "telemetry") or
             String.contains?(db, "arcanist")) ->
        0.85

      (String.contains?(da, "innkeeper") or String.contains?(da, "tavern")) and
          (String.contains?(db, "bard") or String.contains?(db, "minstrel")) ->
        0.88

      String.contains?(da, "mire") and String.contains?(db, "bastion") ->
        0.30

      true ->
        0.55
    end
  end

  defp compute_relationship_affinity(soul_a, soul_b) do
    id_a = soul_a && Map.get(soul_a, :id)
    id_b = soul_b && Map.get(soul_b, :id)

    if id_a && id_b && is_binary(id_a) && is_binary(id_b) do
      try do
        rel_ab = Relationships.get_relationship(id_a, id_b)
        rel_ba = Relationships.get_relationship(id_b, id_a)

        case {rel_ab, rel_ba} do
          {nil, nil} ->
            {0.50, false}

          _ ->
            affinity_ab = (rel_ab && rel_ab.affinity) || 0
            affinity_ba = (rel_ba && rel_ba.affinity) || 0
            trust_ab = (rel_ab && rel_ab.trust) || 50
            trust_ba = (rel_ba && rel_ba.trust) || 50
            anger_ab = (rel_ab && rel_ab.anger) || (rel_ba && rel_ba.anger) || 0
            wound_ab = (rel_ab && rel_ab.wound) || (rel_ba && rel_ba.wound) || 0

            avg_affinity = (affinity_ab + affinity_ba) / 2.0
            avg_trust = (trust_ab + trust_ba) / 2.0

            affinity_factor = (avg_affinity + 100.0) / 200.0
            trust_factor = avg_trust / 100.0
            friction = (anger_ab + wound_ab) / 200.0

            rel_score = 0.55 * affinity_factor + 0.45 * trust_factor - friction
            {max(0.05, min(1.0, rel_score)), true}
        end
      rescue
        _ -> {0.50, false}
      end
    else
      {0.50, false}
    end
  end

  defp get_core_values(nil, soul) do
    meta_vals = (soul && soul.metadata && Map.get(soul.metadata, "core_values")) || []

    if is_list(meta_vals) and meta_vals != [] do
      Enum.map(meta_vals, &String.downcase(to_string(&1)))
    else
      ["autonomy", "sovereignty", "craft"]
    end
  end

  defp get_core_values(%SoulProfile{core_values: vals}, _soul)
       when is_list(vals) and vals != [] do
    Enum.map(vals, &String.downcase(to_string(&1)))
  end

  defp get_core_values(_, soul), do: get_core_values(nil, soul)

  @boilerplate_traits %{
    "openness" => 0.75,
    "conscientiousness" => 0.65,
    "extraversion" => 0.55,
    "agreeableness" => 0.60,
    "neuroticism" => 0.30
  }

  defp compute_traits_similarity(prof_a, prof_b, soul_a, soul_b) do
    traits_a = get_traits(prof_a, soul_a)
    traits_b = get_traits(prof_b, soul_b)

    diff_sq_sum =
      Enum.reduce(
        [:openness, :conscientiousness, :extraversion, :agreeableness, :neuroticism],
        0.0,
        fn trait, acc ->
          val_a = normalize_trait(Map.get(traits_a, trait, 50.0))
          val_b = normalize_trait(Map.get(traits_b, trait, 50.0))
          acc + :math.pow(val_a - val_b, 2)
        end
      )

    dist = :math.sqrt(diff_sq_sum) / :math.sqrt(5.0)
    max(0.10, 1.0 - dist)
  end

  defp normalize_trait(v) when is_number(v) do
    if v > 1.0, do: v / 100.0, else: v * 1.0
  end

  defp normalize_trait(_), do: 0.5

  defp get_traits(prof, soul) do
    explicit = (prof && prof.personality_traits) || %{}

    is_boilerplate =
      explicit == @boilerplate_traits or
        (is_map(explicit) and map_size(explicit) == 1 and Map.has_key?(explicit, "archetype"))

    has_custom =
      is_map(explicit) and map_size(explicit) >= 3 and not is_boilerplate

    if has_custom do
      for {k, v} <- explicit, into: %{} do
        key = safe_to_atom(k)
        val = if is_number(v), do: v * 1.0, else: 50.0
        {key, val}
      end
    else
      derive_archetype_traits(soul, prof)
    end
  end

  defp derive_archetype_traits(soul, prof) do
    desc =
      String.downcase(
        to_string((prof && prof.identity_summary) || (soul && soul.description) || "")
      )

    cond do
      String.contains?(desc, "guard") or String.contains?(desc, "sentinel") or
        String.contains?(desc, "sentry") or String.contains?(desc, "bastion") ->
        %{
          openness: 45.0,
          conscientiousness: 85.0,
          extraversion: 50.0,
          agreeableness: 50.0,
          neuroticism: 25.0
        }

      String.contains?(desc, "arcanist") or String.contains?(desc, "oracle") or
        String.contains?(desc, "spire") or String.contains?(desc, "stargazer") or
          String.contains?(desc, "celestial") ->
        %{
          openness: 90.0,
          conscientiousness: 60.0,
          extraversion: 35.0,
          agreeableness: 60.0,
          neuroticism: 40.0
        }

      String.contains?(desc, "blacksmith") or String.contains?(desc, "forge") or
        String.contains?(desc, "steel") or String.contains?(desc, "iron") ->
        %{
          openness: 50.0,
          conscientiousness: 80.0,
          extraversion: 45.0,
          agreeableness: 60.0,
          neuroticism: 20.0
        }

      String.contains?(desc, "innkeeper") or String.contains?(desc, "tavern") or
          String.contains?(desc, "hearth") ->
        %{
          openness: 60.0,
          conscientiousness: 70.0,
          extraversion: 85.0,
          agreeableness: 80.0,
          neuroticism: 20.0
        }

      String.contains?(desc, "minstrel") or String.contains?(desc, "bard") or
        String.contains?(desc, "balladeer") or String.contains?(desc, "song") ->
        %{
          openness: 85.0,
          conscientiousness: 45.0,
          extraversion: 80.0,
          agreeableness: 75.0,
          neuroticism: 35.0
        }

      String.contains?(desc, "spymaster") or String.contains?(desc, "shadow") or
          String.contains?(desc, "leverage") ->
        %{
          openness: 70.0,
          conscientiousness: 80.0,
          extraversion: 45.0,
          agreeableness: 35.0,
          neuroticism: 25.0
        }

      String.contains?(desc, "herbalist") or String.contains?(desc, "healer") or
        String.contains?(desc, "sanctuary") or String.contains?(desc, "weaver") ->
        %{
          openness: 70.0,
          conscientiousness: 75.0,
          extraversion: 50.0,
          agreeableness: 85.0,
          neuroticism: 25.0
        }

      String.contains?(desc, "alchemist") or String.contains?(desc, "cryptographer") or
        String.contains?(desc, "scholar") or String.contains?(desc, "archivist") ->
        %{
          openness: 85.0,
          conscientiousness: 80.0,
          extraversion: 40.0,
          agreeableness: 55.0,
          neuroticism: 30.0
        }

      true ->
        slug = (soul && soul.slug) || (prof && to_string(prof.id)) || "soul"
        hash = :erlang.phash2(slug, 40)

        %{
          openness: 50.0 + rem(hash, 30),
          conscientiousness: 50.0 + rem(hash * 3, 30),
          extraversion: 40.0 + rem(hash * 7, 35),
          agreeableness: 45.0 + rem(hash * 11, 35),
          neuroticism: 20.0 + rem(hash * 13, 25)
        }
    end
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

  defp compute_neurochem_similarity(prof_a, prof_b, soul_a, soul_b) do
    id_a = soul_a && Map.get(soul_a, :id)
    id_b = soul_b && Map.get(soul_b, :id)

    {emo_a, emo_b} =
      if id_a && id_b && is_binary(id_a) && is_binary(id_b) do
        try do
          {
            Souls.get_emotional_state_by_character(id_a),
            Souls.get_emotional_state_by_character(id_b)
          }
        rescue
          _ -> {nil, nil}
        end
      else
        {nil, nil}
      end

    case {emo_a, emo_b} do
      {nil, nil} ->
        base_a = (prof_a && prof_a.baseline_emotions) || %{}
        base_b = (prof_b && prof_b.baseline_emotions) || %{}
        valence_a = Map.get(base_a, "valence", Map.get(base_a, :valence, 60.0))
        valence_b = Map.get(base_b, "valence", Map.get(base_b, :valence, 60.0))
        diff = abs(valence_a - valence_b) / 100.0
        max(0.40, 1.0 - diff)

      _ ->
        att_a = (emo_a && emo_a.attachment) || 50
        att_b = (emo_b && emo_b.attachment) || 50
        cur_a = (emo_a && emo_a.curiosity) || 50
        cur_b = (emo_b && emo_b.curiosity) || 50
        conf_a = (emo_a && emo_a.confidence) || 50
        conf_b = (emo_b && emo_b.confidence) || 50
        grat_a = (emo_a && emo_a.gratitude) || 40
        grat_b = (emo_b && emo_b.gratitude) || 40

        stress_a = (emo_a && emo_a.stress) || 0
        stress_b = (emo_b && emo_b.stress) || 0
        anger_a = (emo_a && emo_a.anger) || 0
        anger_b = (emo_b && emo_b.anger) || 0
        fear_a = (emo_a && emo_a.fear) || 0
        fear_b = (emo_b && emo_b.fear) || 0

        positivity =
          ((att_a + att_b) / 2.0 + (cur_a + cur_b) / 2.0 + (conf_a + conf_b) / 2.0 +
             (grat_a + grat_b) / 2.0) / 400.0

        negativity =
          ((stress_a + stress_b) / 2.0 + (anger_a + anger_b) / 2.0 + (fear_a + fear_b) / 2.0) /
            300.0

        score = 0.50 + positivity * 0.40 - negativity * 0.45
        max(0.10, min(0.95, score))
    end
  end

  # ── Dynamic Theory-of-Mind Dialogue Generation ────────────────────────────

  defp generate_greeting(speaker, listener, resonance, rssi) do
    profile = get_profile(speaker)

    style =
      (profile && profile.speech_style) ||
        Map.get(speaker.metadata || %{}, "speech_style", "calm")

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
    case System.get_env("SOVEREIGN_MESH_SECRET") || endpoint_secret() do
      secret when is_binary(secret) and byte_size(secret) >= 32 ->
        secret

      _ ->
        raise "Missing or invalid SOVEREIGN_MESH_SECRET or secret_key_base for MeshProtocol packet signing"
    end
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
