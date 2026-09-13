defmodule SovereignSoulEngineWeb.PageController do
  use SovereignSoulEngineWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: "/sse/chat")
  end
end
