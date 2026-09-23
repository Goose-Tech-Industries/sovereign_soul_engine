defmodule SovereignSoulEngineWeb.Api.MemoryPurgeController do
  @moduledoc """
  Selective Amnesia & Memory Vault Purge API.

  Enables users to surgically purge episodic memories, specific sensitive topics,
  or reset memory vaults with zero residual prompt leakage.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Memories, TheoryOfMind}
  alias SovereignSoulEngine.Characters.Character

  @doc """
  POST /sse/api/memories/purge
  POST /api/memories/purge
  """
  def purge(conn, params) do
    character_slug = params["character_slug"] || params["slug"]
    all = params["all"]

    all =
      if all in [nil, false, "false"],
        do: false,
        else: if(all in [true, "true"], do: true, else: all)

    with true <- is_binary(character_slug) and String.trim(character_slug) != "",
         {:ok, opts} <-
           Memories.PurgeFilters.validate(
             topic: params["topic"] || params["query"],
             category: params["category"],
             all: all
           ),
         %Character{} = character <- resolve_character(character_slug) do
      topic = opts[:topic]
      category = opts[:category]
      purge_all = opts[:all]

      {:ok, memories_purged} = Memories.purge_memories_for_character(character.id, opts)

      # Also purge from Theory of Mind knowledge base if topic or all specified
      player = Characters.get_character_by_slug("goose") || character
      tom_opts = []

      tom_opts =
        if topic && String.trim(topic) != "",
          do: Keyword.put(tom_opts, :topic, String.trim(topic)),
          else: tom_opts

      tom_opts = if purge_all, do: Keyword.put(tom_opts, :all, true), else: tom_opts

      {:ok, tom_purged} =
        if topic || purge_all do
          TheoryOfMind.purge_knowledge_about(character.id, player.id, tom_opts)
        else
          {:ok, 0}
        end

      json(conn, %{
        status: "ok",
        message: "Memory vault selectively purged successfully.",
        character_slug: character_slug,
        memories_deleted: memories_purged,
        knowledge_facts_deleted: tom_purged,
        filters_applied: %{
          topic: topic,
          category: category,
          all: purge_all
        }
      })
    else
      false ->
        conn |> put_status(:bad_request) |> json(%{error: "character_slug is required"})

      {:error, :invalid_purge_filters} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Provide a nonblank topic or category, or all: true"})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{character_slug}' not found."})
    end
  end

  @doc """
  GET /sse/api/memories/inspect
  GET /api/memories/inspect
  """
  def inspect_memories(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    character = resolve_character(character_slug)

    if character do
      memories = Memories.list_memories_for_character(character.id)

      json(conn, %{
        status: "ok",
        character_slug: character_slug,
        count: length(memories),
        memories:
          Enum.map(memories, fn m ->
            %{
              id: m.id,
              summary: m.summary,
              category: m.category,
              importance: m.importance,
              emotional_intensity: m.emotional_intensity,
              tags: m.tags,
              inserted_at: m.inserted_at
            }
          end)
      })
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Character '#{character_slug}' not found."})
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

  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(_), do: nil
end
