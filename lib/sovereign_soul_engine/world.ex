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
  alias SovereignSoulEngine.World.WorldEvent

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
  @spec append_event(map()) :: {:ok, WorldEvent.t()} | {:error, Ecto.Changeset.t()}
  def append_event(attrs) do
    %WorldEvent{}
    |> WorldEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Lists recent world events, newest first."
  @spec list_recent_events(keyword()) :: [WorldEvent.t()]
  def list_recent_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(e in WorldEvent, order_by: [desc: e.inserted_at], limit: ^limit)
    |> Repo.all()
  end
end
