defmodule SovereignSoulEngineWeb.Api.WorldController do
  @moduledoc """
  Read-only observability surface for the Soul Society world.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.World

  @doc "GET /sse/api/world/feed"
  def feed(conn, _params) do
    json(conn, World.feed())
  end
end
