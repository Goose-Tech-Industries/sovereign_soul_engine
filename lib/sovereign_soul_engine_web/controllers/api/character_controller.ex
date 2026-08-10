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
