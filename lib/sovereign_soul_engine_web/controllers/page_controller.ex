defmodule SovereignSoulEngineWeb.PageController do
  use SovereignSoulEngineWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
