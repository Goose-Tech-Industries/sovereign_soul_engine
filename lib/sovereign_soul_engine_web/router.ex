defmodule SovereignSoulEngineWeb.Router do
  use SovereignSoulEngineWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SovereignSoulEngineWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/sse", SovereignSoulEngineWeb do
    pipe_through :browser

    live_session :default do
      live "/", DashboardLive, :index
      live "/chat", ChatLive, :index
      live "/chat/sauce", ChatSauceLive, :index
      live "/characters/:id", CharacterLive, :show
      live "/scenes/:id", SceneLive, :show
      live "/ledger", SoulLedgerLive, :index
      live "/memories", MemoryVaultLive, :index
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sovereign_soul_engine, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SovereignSoulEngineWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
