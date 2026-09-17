defmodule SovereignSoulEngine.Souls.SoulCapsule do
  @moduledoc """
  Cryptographic export and import of persistent digital souls (.soul capsule).

  Enables players and developers to truly own, backup, and transport their
  companion across game servers, mobile devices, and local LLM runtimes.

  A Soul Capsule bundles:
  - Identity, archetype, and personality traits
  - Complete neurochemistry and emotional baselines
  - Somatic and circadian states
  - Full memory graph (episodic, core, semantic)
  - Beliefs, desires, goals, subconscious shadows, and active fears
  - The inter-soul relationship graph (resolved by target slug)
  - Cryptographic HMAC-SHA256 integrity checksum (key-derivable)
  """

  require Logger

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.{EmotionalState, SomaticState, SoulShadow, SoulFear}
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Beliefs.CharacterBelief
  alias SovereignSoulEngine.Desires.SoulDesire
  alias SovereignSoulEngine.Goals.CharacterGoal
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Scenes

  import Ecto.Query

  @format_version "sovereign_soul_capsule/v1"

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Exports a complete soul into a portable capsule map.

  Accepts a `Character` struct or a character id. Options:
    - `:secret_key` — the HMAC signing key (falls back to the endpoint
      `secret_key_base`). Supplying an explicit key makes a capsule portable
      and verifiable across engines that share the key.
  """
  @spec export_capsule(String.t() | %Character{}, keyword()) :: {:ok, map()} | {:error, term()}
  def export_capsule(character_or_id, opts \\ [])

  def export_capsule(%Character{} = character, opts) do
    do_export_capsule(character, opts)
  end

  def export_capsule(character_id, opts) when is_binary(character_id) do
    case Characters.get_character(character_id) do
      nil -> {:error, :character_not_found}
      character -> do_export_capsule(character, opts)
    end
  end

  @doc """
  Serializes a soul capsule into a JSON string formatted for .soul files.
  """
  @spec to_json(map()) :: String.t()
  def to_json(capsule) do
    Jason.encode!(capsule, pretty: true)
  end

  @doc """
  Imports a soul capsule from a JSON string or parsed map, reconstituting
  all psychological layers, memories, and the relationship graph.
  """
  @spec import_capsule(String.t() | map(), keyword()) :: {:ok, %Character{}} | {:error, term()}
  def import_capsule(input, opts \\ [])

  def import_capsule(json_string, opts) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, map} -> import_capsule(map, opts)
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  def import_capsule(%{} = capsule, opts) do
    case validate_capsule(capsule, opts) do
      :ok -> reconstitute_soul(capsule, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Internal Export ────────────────────────────────────────────────────────

  defp do_export_capsule(character, opts) do
    profile = Souls.get_soul_profile_by_character(character.id)
    emotional = Souls.get_emotional_state_by_character(character.id)
    somatic = Souls.get_somatic_state_by_character(character.id)

    beliefs = Repo.all(from b in CharacterBelief, where: b.character_id == ^character.id)
    desires = Repo.all(from d in SoulDesire, where: d.character_id == ^character.id)
    goals = Repo.all(from g in CharacterGoal, where: g.character_id == ^character.id)

    memories =
      Repo.all(
        from m in Memory,
          where: m.owner_character_id == ^character.id,
          order_by: [desc: m.inserted_at]
      )

    shadows =
      Repo.all(
        from s in SoulShadow,
          where: s.character_id == ^character.id,
          order_by: [desc: s.inserted_at],
          limit: 20
      )

    fears = Repo.all(from f in SoulFear, where: f.character_id == ^character.id)

    relationships =
      Repo.all(from r in Relationship, where: r.source_character_id == ^character.id)

    payload = %{
      "character" => %{
        "name" => character.name,
        "slug" => character.slug,
        "kind" => character.kind,
        "status" => character.status,
        "description" => character.description
      },
      "soul_profile" =>
        serialize_struct(profile, [
          :personality_traits,
          :attachment_style,
          :identity_summary,
          :speech_style,
          :humor_style,
          :emotional_susceptibility
        ]),
      "emotional_state" =>
        serialize_struct(emotional, [
          :stress,
          :anger,
          :fear,
          :gratitude,
          :confidence,
          :sadness,
          :curiosity,
          :attachment,
          :shame,
          :guilt,
          :rumination_subject,
          :rumination_intensity
        ]),
      "somatic_state" =>
        serialize_struct(somatic, [
          :fatigue,
          :pain,
          :hunger,
          :illness_severity,
          :circadian_chronotype
        ]),
      "beliefs" =>
        Enum.map(
          beliefs,
          &serialize_struct(&1, [
            :belief,
            :domain,
            :conviction,
            :is_challenged,
            :challenged_evidence
          ])
        ),
      "desires" =>
        Enum.map(
          desires,
          &serialize_struct(&1, [:desire, :domain, :urgency, :status, :blocking_belief])
        ),
      "goals" =>
        Enum.map(
          goals,
          &serialize_struct(&1, [
            :goal,
            :current_step,
            :blocker,
            :priority,
            :status,
            :progress_notes
          ])
        ),
      "memories" =>
        Enum.map(
          memories,
          &serialize_struct(&1, [
            :category,
            :summary,
            :details,
            :emotional_intensity,
            :valence,
            :importance,
            :tags
          ])
        ),
      "shadows" =>
        Enum.map(
          shadows,
          &serialize_struct(&1, [
            :private_monologue,
            :repressed_motive,
            :active_defense,
            :emotional_drift
          ])
        ),
      "fears" =>
        Enum.map(fears, &serialize_struct(&1, [:fear_type, :severity, :origin, :status])),
      "relationships" => Enum.map(relationships, &serialize_relationship/1)
    }

    checksum = compute_checksum(payload, opts)

    capsule = %{
      "format" => @format_version,
      "capsule_id" => Ecto.UUID.generate(),
      "engine" => "SovereignSoulEngine/2.0",
      "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "checksum" => checksum,
      "soul" => payload
    }

    {:ok, capsule}
  end

  defp serialize_relationship(rel) do
    target_slug =
      case Characters.get_character(rel.target_character_id) do
        nil -> nil
        target -> target.slug
      end

    %{
      "target_slug" => target_slug,
      "relationship_type" => rel.relationship_type,
      "affinity" => rel.affinity,
      "trust" => rel.trust,
      "respect" => rel.respect,
      "fear" => rel.fear,
      "anger" => rel.anger,
      "gratitude" => rel.gratitude,
      "debt" => rel.debt,
      "wound" => rel.wound,
      "last_interaction_at" =>
        rel.last_interaction_at && DateTime.to_iso8601(rel.last_interaction_at)
    }
  end

  # ── Internal Import ────────────────────────────────────────────────────────

  defp validate_capsule(%{"format" => format, "soul" => soul, "checksum" => checksum}, opts) do
    cond do
      format != @format_version ->
        {:error, :unsupported_capsule_format}

      compute_checksum(soul, opts) != checksum ->
        {:error, :checksum_mismatch_corrupted_capsule}

      true ->
        :ok
    end
  end

  defp validate_capsule(_, _opts), do: {:error, :malformed_capsule_structure}

  defp reconstitute_soul(%{"soul" => soul}, opts) do
    char_data = soul["character"] || %{}
    base_slug = char_data["slug"] || "imported_soul"
    overwrite? = Keyword.get(opts, :overwrite, false)

    slug =
      if overwrite? do
        base_slug
      else
        resolve_slug(base_slug)
      end

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:character, fn _repo, _changes ->
        case Characters.get_character_by_slug(slug) do
          nil ->
            Characters.create_character(%{
              name: char_data["name"] || "Imported Companion",
              slug: slug,
              kind: char_data["kind"] || "npc",
              status: char_data["status"] || "active",
              description: char_data["description"] || "Reconstituted from portable soul capsule."
            })

          existing ->
            Characters.update_character(existing, %{
              name: char_data["name"] || existing.name,
              description: char_data["description"] || existing.description
            })
        end
      end)
      |> Ecto.Multi.run(:profile, fn _repo, %{character: character} ->
        profile_data = soul["soul_profile"] || %{}

        case Souls.get_soul_profile_by_character(character.id) do
          nil ->
            Souls.create_soul_profile(%{
              character_id: character.id,
              attachment_style: profile_data["attachment_style"] || "secure",
              identity_summary: profile_data["identity_summary"],
              speech_style: profile_data["speech_style"],
              humor_style: profile_data["humor_style"],
              personality_traits: profile_data["personality_traits"] || %{}
            })

          existing ->
            Souls.update_soul_profile(existing, %{
              attachment_style: profile_data["attachment_style"] || existing.attachment_style,
              identity_summary: profile_data["identity_summary"] || existing.identity_summary,
              personality_traits:
                profile_data["personality_traits"] || existing.personality_traits
            })
        end
      end)
      |> Ecto.Multi.run(:emotional, fn _repo, %{character: character} ->
        emo_data = soul["emotional_state"] || %{}

        case Souls.get_emotional_state_by_character(character.id) do
          nil ->
            attrs = Map.put(emo_data, "character_id", character.id)
            {:ok, Repo.insert!(EmotionalState.changeset(%EmotionalState{}, attrs))}

          existing ->
            Souls.update_emotional_state(existing, emo_data)
        end
      end)
      |> Ecto.Multi.run(:somatic, fn _repo, %{character: character} ->
        som_data = soul["somatic_state"] || %{}

        case Souls.get_somatic_state_by_character(character.id) do
          nil ->
            attrs = Map.put(som_data, "character_id", character.id)
            {:ok, Repo.insert!(SomaticState.changeset(%SomaticState{}, attrs))}

          existing ->
            Souls.update_somatic_state(existing, som_data)
        end
      end)
      |> Ecto.Multi.run(:memories, fn _repo, %{character: character} ->
        memories = soul["memories"] || []

        Enum.each(memories, fn m ->
          details =
            cond do
              is_map(m["details"]) -> m["details"]
              is_binary(m["details"]) -> %{"narrative" => m["details"]}
              true -> %{}
            end

          Memories.create_memory(%{
            owner_character_id: character.id,
            category: m["category"] || "episodic",
            summary: m["summary"] || "Restored memory",
            details: details,
            emotional_intensity: m["emotional_intensity"] || 50,
            valence: m["valence"] || 0.0,
            importance: m["importance"] || 50,
            tags: m["tags"] || ["capsule_restored"],
            occurred_at: DateTime.utc_now()
          })
        end)

        {:ok, length(memories)}
      end)
      |> Ecto.Multi.run(:beliefs, fn _repo, %{character: character} ->
        restore_beliefs(soul["beliefs"], character.id)
      end)
      |> Ecto.Multi.run(:desires, fn _repo, %{character: character} ->
        restore_desires(soul["desires"], character.id)
      end)
      |> Ecto.Multi.run(:goals, fn _repo, %{character: character} ->
        restore_goals(soul["goals"], character.id)
      end)
      |> Ecto.Multi.run(:shadows, fn _repo, %{character: character} ->
        restore_shadows(soul["shadows"], character)
      end)
      |> Ecto.Multi.run(:fears, fn _repo, %{character: character} ->
        restore_fears(soul["fears"], character.id)
      end)
      |> Ecto.Multi.run(:relationships, fn _repo, %{character: character} ->
        restore_relationships(soul["relationships"], character)
      end)

    case Repo.transaction(multi) do
      {:ok, %{character: character}} ->
        Logger.info(
          "[SoulCapsule] Successfully resurrected #{character.name} (#{character.slug})"
        )

        {:ok, character}

      {:error, step, failed_value, _changes} ->
        Logger.error(
          "[SoulCapsule] Failed importing step #{inspect(step)}: #{inspect(failed_value)}"
        )

        {:error, {step, failed_value}}
    end
  end

  # ── Restoration helpers ────────────────────────────────────────────────────

  defp restore_beliefs(beliefs, character_id) do
    (beliefs || [])
    |> Enum.each(fn b ->
      Souls.create_belief(%{
        character_id: character_id,
        belief: b["belief"] || "Restored belief",
        domain: b["domain"] || "world",
        conviction: b["conviction"] || 50,
        is_challenged: b["is_challenged"] || false,
        challenged_evidence: b["challenged_evidence"]
      })
    end)

    {:ok, length(beliefs || [])}
  end

  defp restore_desires(desires, character_id) do
    (desires || [])
    |> Enum.each(fn d ->
      Souls.create_desire(%{
        character_id: character_id,
        desire: d["desire"] || "Restored desire",
        domain: d["domain"] || "connection",
        urgency: d["urgency"] || 50,
        status: d["status"] || "active",
        blocking_belief: d["blocking_belief"]
      })
    end)

    {:ok, length(desires || [])}
  end

  defp restore_goals(goals, character_id) do
    (goals || [])
    |> Enum.each(fn g ->
      Souls.create_goal(%{
        character_id: character_id,
        goal: g["goal"] || "Restored goal",
        current_step: g["current_step"],
        blocker: g["blocker"],
        priority: g["priority"] || 50,
        status: g["status"] || "active",
        progress_notes: g["progress_notes"]
      })
    end)

    {:ok, length(goals || [])}
  end

  defp restore_shadows(shadows, character) do
    case shadows || [] do
      [] ->
        {:ok, 0}

      list ->
        scene_id = ensure_import_scene(character)

        Enum.each(list, fn s ->
          Souls.create_soul_shadow(%{
            character_id: character.id,
            scene_id: scene_id,
            private_monologue: s["private_monologue"],
            repressed_motive: s["repressed_motive"],
            active_defense: s["active_defense"] || "none",
            emotional_drift: s["emotional_drift"]
          })
        end)

        {:ok, length(list)}
    end
  end

  defp restore_fears(fears, character_id) do
    (fears || [])
    |> Enum.each(fn f ->
      Souls.create_soul_fear(%{
        character_id: character_id,
        fear_type: f["fear_type"] || "unknown",
        severity: f["severity"] || 50,
        origin: f["origin"] || "baked_in",
        status: f["status"] || "active"
      })
    end)

    {:ok, length(fears || [])}
  end

  defp restore_relationships(relationships, character) do
    {resolved, unresolved} =
      (relationships || [])
      |> Enum.reduce({0, []}, fn rel, {resolved, unresolved} ->
        target = rel["target_slug"] && Characters.get_character_by_slug(rel["target_slug"])

        if target do
          Relationships.create_relationship(%{
            source_character_id: character.id,
            target_character_id: target.id,
            relationship_type: rel["relationship_type"] || "acquaintance",
            affinity: rel["affinity"] || 0,
            trust: rel["trust"] || 0,
            respect: rel["respect"] || 0,
            fear: rel["fear"] || 0,
            anger: rel["anger"] || 0,
            gratitude: rel["gratitude"] || 0,
            debt: rel["debt"] || 0,
            wound: rel["wound"] || 0,
            last_interaction_at: parse_datetime(rel["last_interaction_at"])
          })

          {resolved + 1, unresolved}
        else
          {resolved, [rel | unresolved]}
        end
      end)

    if unresolved != [] do
      current_meta = character.metadata || %{}
      pending = current_meta["unresolved_relationships"] || []
      new_meta = Map.put(current_meta, "unresolved_relationships", pending ++ unresolved)
      Characters.update_character(character, %{metadata: new_meta})
    end

    {:ok, resolved}
  end

  defp ensure_import_scene(character) do
    case Scenes.create_scene(%{title: "Capsule Import — #{character.name}", status: "active"}) do
      {:ok, scene} -> scene.id
      {:error, _} -> nil
    end
  end

  defp resolve_slug(base_slug) do
    case Characters.get_character_by_slug(base_slug) do
      nil -> base_slug
      _ -> "#{base_slug}_#{:erlang.phash2(:erlang.monotonic_time(), 10_000)}"
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil

  # ── Cryptographic Checksum & Serialization Helpers ─────────────────────────

  defp compute_checksum(payload, opts) do
    serialized = payload |> canonicalize() |> Jason.encode!()
    :crypto.mac(:hmac, :sha256, signing_key(opts), serialized) |> Base.encode16(case: :lower)
  end

  # Derives the HMAC signing key. An explicit `opts[:secret_key]` wins; otherwise
  # the endpoint `secret_key_base` (or `SECRET_KEY_BASE`) is used so the checksum
  # is verifiable across nodes that share the same secret, instead of a shared
  # compile-time salt.
  defp signing_key(opts) do
    cond do
      is_binary(opts[:secret_key]) and byte_size(opts[:secret_key]) > 0 ->
        opts[:secret_key]

      true ->
        endpoint = Application.get_env(:sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint)

        (endpoint && endpoint[:secret_key_base]) ||
          System.get_env("SECRET_KEY_BASE") ||
          "sovereign_soul_capsule_insecure_fallback_secret"
    end
  end

  # Canonical JSON (key-sorted, recursively) so the checksum is byte-stable
  # across engines regardless of map insertion order.
  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {to_string(k), canonicalize(v)} end)
    |> Jason.OrderedObject.new()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value

  defp serialize_struct(nil, _fields), do: %{}

  defp serialize_struct(struct, fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      val = Map.get(struct, field)
      Map.put(acc, to_string(field), val)
    end)
  end
end
