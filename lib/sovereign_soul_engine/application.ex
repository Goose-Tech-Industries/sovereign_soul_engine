defmodule SovereignSoulEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SovereignSoulEngineWeb.Telemetry,
      SovereignSoulEngine.Repo,
      {DNSCluster,
       query: Application.get_env(:sovereign_soul_engine, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SovereignSoulEngine.PubSub},
      SovereignSoulEngine.Runtime.NPCRegistry,
      SovereignSoulEngine.Runtime.NPCSupervisor,
      # Start to serve requests, typically the last entry
      SovereignSoulEngineWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SovereignSoulEngine.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SovereignSoulEngineWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
