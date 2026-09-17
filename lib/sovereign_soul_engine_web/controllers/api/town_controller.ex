defmodule SovereignSoulEngineWeb.Api.TownController do
  @moduledoc """
  REST API for Feannag's Rest (Gleann Caorach) town map & spatial simulation.
  1:1 compatible with Twisted Paradox tile matrices and external game clients.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.World.TownMap

  @doc "GET /sse/api/town/map - Full 12-district map overview with live souls."
  def map(conn, _params) do
    json(conn, TownMap.get_map())
  end

  @doc "GET /sse/api/town/districts/:slug - Detailed district data."
  def district(conn, %{"slug" => slug}) do
    case TownMap.get_district(slug) do
      nil ->
        put_status(conn, :not_found)
        |> json(%{error: "district_not_found", slug: slug})

      district ->
        json(conn, district)
    end
  end

  @doc "POST /sse/api/town/districts/:slug/expand - Use AI to discover a new secret/POI."
  def expand_district(conn, %{"slug" => slug} = params) do
    prompt = params["prompt"] || ""

    case TownMap.expand_district_with_ai(slug, prompt) do
      {:ok, expansion} ->
        json(conn, %{status: "ok", district: slug, expansion: expansion})

      {:error, reason} ->
        put_status(conn, :unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  @doc "POST /sse/api/town/simulate_movements - Trigger souls roaming to connected districts."
  def simulate_movements(conn, _params) do
    {:ok, count} = TownMap.simulate_roaming()
    json(conn, %{status: "ok", moved_souls: count})
  end

  @doc "POST /sse/api/town/move_soul - Move a specific soul to a target district."
  def move_soul(conn, %{"character_id" => char_id, "district_slug" => target_slug}) do
    case TownMap.move_soul(char_id, target_slug) do
      {:ok, res} ->
        json(conn, %{status: "ok", move: res})

      {:error, reason} ->
        put_status(conn, :bad_request)
        |> json(%{error: to_string(reason)})
    end
  end
end
