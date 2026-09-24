defmodule SovereignSoulEngineWeb.Api.DreamController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Souls.DreamEngine

  @doc """
  GET /sse/api/souls/dream
  GET /api/souls/dream
  """
  def show(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case DreamEngine.get_latest_dream(character_slug) do
      {:ok, dream} ->
        {:ok, journal} = DreamEngine.list_dream_journal(character_slug)

        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          latest_dream: dream,
          journal_count: length(journal)
        })

      {:error, :no_dreams_yet} ->
        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          latest_dream: nil,
          message:
            "No dream states recorded yet. Trigger consolidation to initiate REM dream cycle."
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  POST /sse/api/souls/dream
  POST /api/souls/dream
  """
  def trigger(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case DreamEngine.consolidate_and_dream(character_slug) do
      {:ok, dream} ->
        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          message: "Subconscious REM memory consolidation completed.",
          dream: dream
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
