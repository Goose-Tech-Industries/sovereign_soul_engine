defmodule SovereignSoulEngineWeb.Api.CharacterController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Souls}
  alias SovereignSoulEngine.Souls.IntentEngine

  @doc "Active NPCs external systems (e.g. carnage_v2) can place in a world."
  def index(conn, _params) do
    npcs =
      Characters.list_characters()
      |> Enum.filter(&(&1.kind == "npc" and &1.status == "active"))
      |> Enum.map(fn c ->
        %{id: c.id, name: c.name, slug: c.slug, description: c.description}
      end)

    json(conn, %{characters: npcs})
  end

  @doc "Creates a new character and seeds their psychological soul profile, emotional baseline, and somatic state."
  def create(conn, params) do
    name = params["name"] || "Unknown"

    slug =
      (params["slug"] || name)
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "-")
      |> String.trim("-")

    description = params["description"] || params["persona"] || ""
    kind = params["kind"] || "npc"

    with {:ok, character} <-
           Characters.create_character(%{
             name: name,
             slug: slug,
             kind: kind,
             description: description,
             status: "active"
           }) do
      traits =
        params["personality_traits"] || params["traits"] || %{"loyalty" => 75, "curiosity" => 60}

      baseline =
        params["baseline_emotions"] || %{"confidence" => 60, "curiosity" => 50, "stress" => 15}

      {:ok, soul} =
        Souls.create_soul_profile(%{
          character_id: character.id,
          attachment_style: params["attachment_style"] || "secure",
          humor_style: params["humor_style"] || "witty",
          emotional_susceptibility: params["emotional_susceptibility"] || 40,
          speech_style: params["speech_style"] || "direct",
          personality_traits: traits,
          core_values: params["core_values"] || ["Honor", "Freedom"],
          baseline_emotions: baseline,
          physical_tells: params["physical_tells"] || %{"stress" => "taps fingers rhythmically"},
          social_stamina: 80,
          stamina_regen_rate: 10,
          stamina_max: 100
        })

      {:ok, _emotional} =
        Souls.create_emotional_state(%{
          character_id: character.id,
          anger: Map.get(baseline, "anger", 0),
          fear: Map.get(baseline, "fear", 0),
          stress: Map.get(baseline, "stress", 15),
          gratitude: Map.get(baseline, "gratitude", 25),
          confidence: Map.get(baseline, "confidence", 60),
          sadness: Map.get(baseline, "sadness", 0)
        })

      {:ok, _somatic} =
        Souls.create_somatic_state(%{
          character_id: character.id,
          hunger: 0,
          pain: 0,
          fatigue: 10,
          illness_severity: 0
        })

      json(conn, %{
        status: "ok",
        character_id: character.id,
        slug: character.slug,
        name: character.name,
        soul_profile_id: soul.id,
        traits: traits,
        baseline_emotions: baseline
      })
    else
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create character", details: inspect(changeset)})
    end
  end

  @doc "Inspects a character's complete soul, emotional, and somatic state (God-Eye view)."
  def show(conn, %{"id" => id_or_slug}) do
    character =
      case Ecto.UUID.cast(id_or_slug) do
        {:ok, uuid} -> Characters.get_character(uuid)
        _ -> Characters.get_character_by_slug(id_or_slug)
      end

    if character do
      soul = Souls.get_soul_profile_by_character(character.id)
      emotional = Souls.get_emotional_state_by_character(character.id)
      somatic = Souls.get_somatic_state_by_character(character.id)

      json(conn, %{
        id: character.id,
        name: character.name,
        slug: character.slug,
        kind: character.kind,
        description: character.description,
        soul_profile:
          soul &&
            %{
              attachment_style: soul.attachment_style,
              humor_style: soul.humor_style,
              traits: soul.personality_traits,
              core_values: soul.core_values,
              speech_style: soul.speech_style,
              physical_tells: soul.physical_tells
            },
        emotional_state:
          emotional &&
            %{
              anger: emotional.anger,
              fear: emotional.fear,
              stress: emotional.stress,
              gratitude: emotional.gratitude,
              confidence: emotional.confidence,
              sadness: emotional.sadness
            },
        somatic_state:
          somatic &&
            %{
              hunger: somatic.hunger,
              pain: somatic.pain,
              fatigue: somatic.fatigue
            }
      })
    else
      conn |> put_status(:not_found) |> json(%{error: "character not found"})
    end
  end

  @doc """
  This NPC's current spatial disposition — wander / idle / seek / flee —
  decided deterministically from their emotional and somatic state. No
  spatial data (this engine doesn't know about maps or tiles); callers
  are expected to translate the intent into an actual move using their
  own terrain knowledge.
  """
  def intent(conn, %{"id" => id}) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         character when not is_nil(character) <- Characters.get_character(id) do
      emotional = Souls.get_emotional_state_by_character(character.id)
      somatic = Souls.get_somatic_state_by_character(character.id)
      result = IntentEngine.decide(emotional, somatic)

      json(conn, %{
        character_id: character.id,
        intent: result.intent,
        reason: result.reason
      })
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "character not found"})
    end
  end
end
