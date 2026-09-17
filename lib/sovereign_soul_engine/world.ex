defmodule SovereignSoulEngine.World do
  @moduledoc """
  The non-tenant, always-on Soul Society world (RFC-0002 §6).

  The world is a singleton autonomous scene plus an append-only, compactable
  event ledger. Raw turn chatter never touches Postgres; only memorable, signed
  events are appended.
  """

  import Ecto.Query, warn: false

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Scenes.Scene
  alias SovereignSoulEngine.Scenes.SceneParticipant
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Moderation
  alias SovereignSoulEngine.World.WorldEvent
  alias SovereignSoulEngine.World.SeedSouls

  @world_source "world"
  @world_id "sovereign-society"

  @doc "Returns the singleton world scene, or nil if it has not been created."
  @spec world_scene() :: Scene.t() | nil
  def world_scene do
    Repo.get_by(Scene, external_source: @world_source, external_id: @world_id)
  end

  @doc "Finds or creates the always-on world scene (idempotent, race-safe)."
  @spec ensure_world_scene() :: Scene.t()
  def ensure_world_scene do
    case world_scene() do
      nil ->
        %Scene{}
        |> Scene.changeset(%{
          title: "Soul Society",
          status: "active",
          location: "Sovereign Society",
          is_autonomous: true,
          external_source: @world_source,
          external_id: @world_id,
          started_at: DateTime.utc_now()
        })
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:external_source, :external_id])

        world_scene()

      scene ->
        scene
    end
  end

  @doc "Appends a world event to the ledger. Returns `{:ok, event}` or `{:error, changeset}`."
  @spec append_event(map()) :: {:ok, WorldEvent.t()} | {:error, term()}
  def append_event(attrs) do
    case Moderation.screen(attrs) do
      :ok ->
        case %WorldEvent{} |> WorldEvent.changeset(attrs) |> Repo.insert() do
          {:ok, event} ->
            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              "world:feed",
              {:world_event, event}
            )

            {:ok, event}

          error ->
            error
        end

      {:error, reason} ->
        {:error, {:moderated, reason}}
    end
  end

  @doc "Lists recent world events, newest first."
  @spec list_recent_events(keyword()) :: [WorldEvent.t()]
  def list_recent_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in WorldEvent, order_by: [desc: e.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  @doc "Seeds the 50 founding souls into the Soul Society, idempotently."
  @spec seed_souls() :: {:ok, non_neg_integer()}
  def seed_souls, do: SeedSouls.seed_all()

  @doc "All active NPC souls participating in the world scene."
  @spec world_souls() :: [Scene.t()]
  def world_souls do
    case world_scene() do
      nil ->
        []

      scene ->
        from(sp in SceneParticipant,
          join: c in assoc(sp, :character),
          where: sp.scene_id == ^scene.id and c.kind == "npc" and c.status == "active",
          select: c,
          distinct: true
        )
        |> Repo.all()
    end
  end

  @doc """
  A live summary of the world: soul count, relationship count, and recent events.
  The observability surface the world feed (and any dashboard) reads.
  """
  @spec feed(keyword()) :: map()
  def feed(opts \\ []) do
    %{
      scene_id: world_scene() && world_scene().id,
      souls: soul_count(),
      relationships: relationship_count(),
      recent_events: recent_events(Keyword.get(opts, :limit, 20))
    }
  end

  defp soul_count do
    case world_scene() do
      nil ->
        0

      scene ->
        from(sp in SceneParticipant, where: sp.scene_id == ^scene.id)
        |> Repo.aggregate(:count)
    end
  end

  defp relationship_count do
    Repo.aggregate(Relationship, :count)
  end

  defp recent_events(limit) do
    list_recent_events(limit: limit)
    |> Enum.map(fn e ->
      %{
        kind: e.kind,
        from: e.from_did,
        to: e.to_did,
        payload: e.payload,
        at: e.inserted_at
      }
    end)
  end

  @doc """
  Physically removes compacted world events older than `before` (default 30 days).
  This is the anti-bloat deletion step — `WorldCompactor` summarizes, this purges.
  Returns the number of rows deleted.
  """
  @spec purge_events(DateTime.t()) :: non_neg_integer()
  def purge_events(before \\ DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)) do
    from(e in WorldEvent, where: e.compacted == true and e.inserted_at < ^before)
    |> Repo.delete_all()
    |> then(fn {count, _} -> count end)
  end
end
