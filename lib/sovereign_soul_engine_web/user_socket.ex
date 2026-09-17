defmodule SovereignSoulEngineWeb.UserSocket do
  use Phoenix.Socket

  channel "soul:*", SovereignSoulEngineWeb.SoulChannel
  channel "encounter:*", SovereignSoulEngineWeb.SoulChannel
  channel "world:sovereign-society", SovereignSoulEngineWeb.SoulChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
