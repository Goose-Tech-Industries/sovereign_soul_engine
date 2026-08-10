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
    plug SovereignSoulEngineWeb.Plugs.ApiAuth
    plug SovereignSoulEngineWeb.Plugs.RateLimit
  end

  # Scoped under /sse to match every other route in this app (see
  # endpoint.ex's `socket "/sse/live"` and `Plug.Static at: "/sse"`) —
  # nginx passes the full request URI through unchanged for this app,
  # unlike carnage_v2 which strips its prefix.
  scope "/sse/api", SovereignSoulEngineWeb.Api do
    pipe_through :api

    get "/characters", CharacterController, :index
    get "/characters/:id/intent", CharacterController, :intent

    post "/npc_chat", NpcChatController, :send_message
    get "/npc_chat/history", NpcChatController, :history
    get "/npc_chat/relationship", NpcChatController, :relationship

    post "/ambient_chat/message", AmbientChatController, :message
    post "/ambient_chat/npc_reply", AmbientChatController, :npc_reply

    get "/npc_actions/pending", NpcActionsController, :pending
    post "/npc_actions/:id/consume", NpcActionsController, :consume
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

  scope "/sse/acp", SovereignSoulEngineWeb do
    pipe_through :browser

    live_session :acp do
      live "/", AcpDashboardLive, :index
      live "/npcs/new", AcpNpcCreatorLive, :new
      live "/npcs/:id", AcpCharacterLive, :show
      live "/npcs/:id/:tab", AcpCharacterLive, :show
      live "/social", AcpSocialLogLive, :index
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
