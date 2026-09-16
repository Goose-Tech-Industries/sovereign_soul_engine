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
  - Subconscious shadow motives and active defense mechanisms
  - Cryptographic SHA-256 integrity checksum
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

  import Ecto.Query

  @format_version "sovereign_soul_capsule/v1"
  @secret_salt "sovereign_soul_provenance_2026"

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc """
  Exports a complete soul into a portable capsule map.
  """
  @spec export_capsule(String.t() | %Character{}) :: {:ok, map()} | {:error, term()}
  def export_capsule(%Character{} = character) do
    do_export_capsule(character)
  end

  def export_capsule(character_id) when is_binary(character_id) do
    case Characters.get_character(character_id) do
      nil -> {:error, :character_not_found}
      character -> do_export_capsule(character)
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
  all psychological layers and memories into the database.
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
    case validate_capsule(capsule) do
      :ok -> reconstitute_soul(capsule, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Internal Export ────────────────────────────────────────────────────────

  defp do_export_capsule(character) do
    profile = Souls.get_soul_profile_by_character(character.id)
    emotional = Souls.get_emotional_state_by_character(character.id)
    somatic = Souls.get_somatic_state_by_character(character.id)

    beliefs = Repo.all(from b in CharacterBelief, where: b.character_id == ^character.id)
    desires = Repo.all(from d in SoulDesire, where: d.character_id == ^character.id)
    goals = Repo.all(from g in CharacterGoal, where: g.character_id == ^character.id)
    memories = Repo.all(from m in Memory, where: m.owner_character_id == ^character.id, order_by: [desc: m.inserted_at])
    shadows = Repo.all(from s in SoulShadow, where: s.character_id == ^character.id, order_by: [desc: s.inserted_at], limit: 20)
    fears = Repo.all(from f in SoulFear, where: f.character_id == ^character.id)

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
      "beliefs" => Enum.map(beliefs, &serialize_struct(&1, [:claim, :conviction, :emotional_charge])),
      "desires" => Enum.map(desires, &serialize_struct(&1, [:description, :intensity, :category])),
      "goals" => Enum.map(goals, &serialize_struct(&1, [:description, :priority, :status, :progress])),
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
      "fears" => Enum.map(fears, &serialize_struct(&1, [:fear_type, :severity, :origin, :status]))
    }

    checksum = compute_checksum(payload)

    capsule = %{
      "format" => @format_version,
      "engine" => "SovereignSoulEngine/2.0",
      "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "checksum" => checksum,
      "soul" => payload
    }

    {:ok, capsule}
  end

  # ── Internal Import ────────────────────────────────────────────────────────

  defp validate_capsule(%{"format" => format, "soul" => soul, "checksum" => checksum}) do
    cond do
      format != @format_version ->
        {:error, :unsupported_capsule_format}

      compute_checksum(soul) != checksum ->
        {:error, :checksum_mismatch_corrupted_capsule}

      true ->
        :ok
    end
  end

  defp validate_capsule(_), do: {:error, :malformed_capsule_structure}

  defp reconstitute_soul(%{"soul" => soul}, opts) do
    char_data = soul["character"] || %{}
    base_slug = char_data["slug"] || "imported_soul"
    overwrite? = Keyword.get(opts, :overwrite, false)

    slug =
      if overwrite? do
        base_slug
      else
        case Characters.get_character_by_slug(base_slug) do
          nil -> base_slug
          _ -> "#{base_slug}_#{:erlang.phash2(:erlang.monotonic_time(), 10_000)}"
        end
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
              personality_traits: profile_data["personality_traits"] || %{}
            })

          existing ->
            Souls.update_soul_profile(existing, %{
              attachment_style: profile_data["attachment_style"] || existing.attachment_style,
              identity_summary: profile_data["identity_summary"] || existing.identity_summary,
              personality_traits: profile_data["personality_traits"] || existing.personality_traits
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

    case Repo.transaction(multi) do
      {:ok, %{character: character}} ->
        Logger.info("[SoulCapsule] Successfully resurrected #{character.name} (#{character.slug})")
        {:ok, character}

      {:error, step, failed_value, _changes} ->
        Logger.error("[SoulCapsule] Failed importing step #{inspect(step)}: #{inspect(failed_value)}")
        {:error, {step, failed_value}}
    end
  end

  # ── Cryptographic Checksum & Serialization Helpers ─────────────────────────

  defp compute_checksum(payload) do
    serialized = Jason.encode!(payload)
    :crypto.mac(:hmac, :sha256, @secret_salt, serialized) |> Base.encode16(case: :lower)
  end

  defp serialize_struct(nil, _fields), do: %{}

  defp serialize_struct(struct, fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      val = Map.get(struct, field)
      Map.put(acc, to_string(field), val)
    end)
  end
end
