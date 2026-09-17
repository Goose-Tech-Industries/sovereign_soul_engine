defmodule SovereignSoulEngineWeb.Api.EdgeController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Edge.SurvivalMode

  @doc """
  GET /sse/api/edge/status
  GET /api/edge/status
  """
  def status(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    info = SurvivalMode.current_status(character_slug)

    json(conn, %{
      status: "ok",
      character_slug: character_slug,
      edge: info
    })
  end

  @doc """
  POST /sse/api/edge/toggle
  POST /api/edge/toggle
  """
  def toggle(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    enabled = Map.get(params, "enabled", true)

    case SurvivalMode.toggle_force_offline(character_slug, enabled) do
      {:ok, settings} ->
        info = SurvivalMode.current_status(character_slug)

        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          force_local_offline: enabled,
          edge: info,
          settings: settings
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
