defmodule SovereignSoulEngineWeb.Api.CircadianController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Souls.CircadianEngine
  alias SovereignSoulEngine.Privacy

  @doc """
  GET /sse/api/circadian/status
  GET /api/circadian/status
  """
  def status(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    status = CircadianEngine.current_state(character_slug)

    json(conn, %{
      status: "ok",
      character_slug: character_slug,
      circadian: status
    })
  end

  @doc """
  POST /sse/api/circadian/chronotype
  POST /api/circadian/chronotype
  """
  def update_chronotype(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    chronotype = params["chronotype"] || "night_owl"

    case Privacy.update_settings(character_slug, %{"chronotype" => chronotype}) do
      {:ok, settings} ->
        new_status = CircadianEngine.current_state(character_slug)

        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          chronotype: chronotype,
          circadian: new_status,
          settings: settings
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
