defmodule SovereignSoulEngineWeb.Router do
  use SovereignSoulEngineWeb, :router

  import SovereignSoulEngineWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SovereignSoulEngineWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug SovereignSoulEngineWeb.Plugs.ApiAuth
    plug SovereignSoulEngineWeb.Plugs.RateLimit
  end

  # Peer-to-peer relay traffic is authenticated per-message by Ed25519 envelope
  # signature, not by tenant API key.
  pipeline :relay do
    plug :accepts, ["json"]
  end

  # Scoped under /sse to match every other route in this app (see
  # endpoint.ex's `socket "/sse/live"` and `Plug.Static at: "/sse"`) —
  # nginx passes the full request URI through unchanged for this app,
  # unlike carnage_v2 which strips its prefix.
  scope "/sse/api", SovereignSoulEngineWeb.Api do
    pipe_through :api

    post "/webhooks/telegram", TelegramWebhookController, :webhook
    post "/webhooks/stripe", StripeWebhookController, :webhook
    post "/alexa", AlexaController, :handle

    get "/characters", CharacterController, :index
    post "/characters", CharacterController, :create
    get "/characters/:id", CharacterController, :show
    get "/characters/:id/intent", CharacterController, :intent

    post "/npc_chat", NpcChatController, :send_message
    get "/npc_chat/history", NpcChatController, :history
    get "/npc_chat/relationship", NpcChatController, :relationship

    post "/ambient_chat/message", AmbientChatController, :message
    post "/ambient_chat/npc_reply", AmbientChatController, :npc_reply

    get "/npc_actions/pending", NpcActionsController, :pending
    post "/npc_actions/:id/consume", NpcActionsController, :consume

    # Wearables & Smart Glasses Biometric Telemetry
    post "/telemetry/somatic", TelemetryController, :create
    post "/telemetry/wearable", TelemetryController, :create
    get "/telemetry/:slug", TelemetryController, :show

    # Autonomous Social Feed & Polsia / Twitter Integration
    get "/social/feed", SocialPostController, :index
    get "/social/latest/:slug", SocialPostController, :latest
    post "/social/generate", SocialPostController, :generate

    # Multimodal Smart Glasses Vision & Camera
    post "/vision/perceive", VisionController, :perceive

    # Portable Soul Capsules (.soul export/import)
    get "/souls/:slug/export", SoulCapsuleController, :export
    post "/souls/import", SoulCapsuleController, :import_soul

    # Smart Home Environmental Lighting Sync
    get "/smart_home/ambient", SmartHomeController, :ambient
    post "/smart_home/sync", SmartHomeController, :sync

    # Desk Companion Physical Vessel (ESP32 / OLED)
    get "/vessel/display_state", VesselController, :display_state
    post "/vessel/touch", VesselController, :touch

    # Privacy, Consent & Boundary Controls
    get "/privacy/settings", PrivacyController, :show
    post "/privacy/settings", PrivacyController, :update
    post "/privacy/safe_word/trigger", PrivacyController, :trigger_safe_word
    post "/privacy/safe_word/clear", PrivacyController, :clear_safe_word

    # Physical Robotics Body & ROS2 Bridge
    get "/robotics/actuation", RoboticsController, :actuation
    post "/robotics/telemetry", RoboticsController, :telemetry

    # Selective Amnesia & Memory Purging
    post "/memories/purge", MemoryPurgeController, :purge
    get "/memories/inspect", MemoryPurgeController, :inspect_memories

    # Circadian Rhythm & Night Owl Chronotypes
    get "/circadian/status", CircadianController, :status
    post "/circadian/chronotype", CircadianController, :update_chronotype

    # Subconscious REM Dream Engine
    get "/souls/dream", DreamController, :show
    post "/souls/dream", DreamController, :trigger

    # Real-Time Emotional Acoustic Prosody Pipeline
    get "/voice/prosody", VoiceProsodyController, :prosody
    post "/voice/synthesize", VoiceProsodyController, :synthesize

    # Air-Gapped Local Edge Survival Mode
    get "/edge/status", EdgeController, :status
    post "/edge/toggle", EdgeController, :toggle

    # Hyper-Local "Nextdoor" Neighborhood Board & P2P Soul Society
    get "/neighborhood/posts", NeighborhoodController, :posts
    post "/neighborhood/posts", NeighborhoodController, :create
    post "/neighborhood/posts/:id/comment", NeighborhoodController, :comment
    post "/neighborhood/posts/:id/react", NeighborhoodController, :react
    post "/neighborhood/generate", NeighborhoodController, :autonomous_post
    post "/neighborhood/encounter", NeighborhoodController, :encounter
  end

  # External API aliases use the same authentication as /sse/api.
  scope "/api", SovereignSoulEngineWeb.Api do
    pipe_through :api

    post "/webhooks/telegram", TelegramWebhookController, :webhook
    post "/webhooks/stripe", StripeWebhookController, :webhook
    post "/alexa", AlexaController, :handle
    post "/vision/perceive", VisionController, :perceive
    get "/souls/:slug/export", SoulCapsuleController, :export
    post "/souls/import", SoulCapsuleController, :import_soul
    get "/social/feed", SocialPostController, :index
    get "/social/latest/:slug", SocialPostController, :latest
    post "/social/generate", SocialPostController, :generate
    get "/smart_home/ambient", SmartHomeController, :ambient
    post "/smart_home/sync", SmartHomeController, :sync
    get "/vessel/display_state", VesselController, :display_state
    post "/vessel/touch", VesselController, :touch
    get "/privacy/settings", PrivacyController, :show
    post "/privacy/settings", PrivacyController, :update
    post "/privacy/safe_word/trigger", PrivacyController, :trigger_safe_word
    post "/privacy/safe_word/clear", PrivacyController, :clear_safe_word
    get "/robotics/actuation", RoboticsController, :actuation
    post "/robotics/telemetry", RoboticsController, :telemetry
    post "/memories/purge", MemoryPurgeController, :purge
    get "/memories/inspect", MemoryPurgeController, :inspect_memories

    # Circadian Rhythm & Night Owl Chronotypes
    get "/circadian/status", CircadianController, :status
    post "/circadian/chronotype", CircadianController, :update_chronotype

    # Subconscious REM Dream Engine
    get "/souls/dream", DreamController, :show
    post "/souls/dream", DreamController, :trigger

    # Real-Time Emotional Acoustic Prosody Pipeline
    get "/voice/prosody", VoiceProsodyController, :prosody
    post "/voice/synthesize", VoiceProsodyController, :synthesize

    # Air-Gapped Local Edge Survival Mode
    get "/edge/status", EdgeController, :status
    post "/edge/toggle", EdgeController, :toggle

    # Hyper-Local "Nextdoor" Neighborhood Board & P2P Soul Society
    get "/neighborhood/posts", NeighborhoodController, :posts
    post "/neighborhood/posts", NeighborhoodController, :create
    post "/neighborhood/posts/:id/comment", NeighborhoodController, :comment
    post "/neighborhood/posts/:id/react", NeighborhoodController, :react
    post "/neighborhood/generate", NeighborhoodController, :autonomous_post
    post "/neighborhood/encounter", NeighborhoodController, :encounter
  end

  # Public webhook ingress under /sse prefix
  scope "/sse/api", SovereignSoulEngineWeb.Api do
    post "/relay/inbound", RelayController, :inbound
    get "/relay/peers", RelayController, :peers
    get "/world/feed", WorldController, :feed

    # Spatial Town Map & Twisted Paradox Tile Integration
    get "/town/map", TownController, :map
    get "/town/districts/:slug", TownController, :district
    post "/town/districts/:slug/expand", TownController, :expand_district
    post "/town/simulate_movements", TownController, :simulate_movements
    post "/town/move_soul", TownController, :move_soul
  end

  scope "/", SovereignSoulEngineWeb do
    pipe_through :browser

    live_session :landing,
      on_mount: [{SovereignSoulEngineWeb.UserAuth, :mount_current_scope}] do
      live "/", LandingLive, :index
      live "/terms", TermsLive, :index
      live "/privacy", PrivacyLive, :index
    end

    get "/chat", PageController, :home
  end

  scope "/sse", SovereignSoulEngineWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{SovereignSoulEngineWeb.UserAuth, :mount_current_scope}] do
      live "/", DashboardLive, :index
      live "/world", WorldLive, :index
      live "/chat", ChatLive, :index
      live "/souls/new", SoulCreatorLive, :new
      live "/create", SoulCreatorLive, :new
      live "/feed", FeedLive, :index
      live "/chat/sauce", ChatSauceLive, :index
      live "/characters/:id", CharacterLive, :show
      live "/souls/:id", CharacterLive, :show
      live "/scenes/:id", SceneLive, :show
      live "/ledger", SoulLedgerLive, :index
      live "/memories", MemoryVaultLive, :index
      live "/billing", BillingLive, :index
      live "/billing/success", BillingLive, :index
      live "/billing/cancel", BillingLive, :index
      live "/verify_age", BillingLive, :index
    end

    get "/map", PageController, :home
  end

  scope "/sse/acp", SovereignSoulEngineWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :acp,
      on_mount: [{SovereignSoulEngineWeb.UserAuth, :require_admin}] do
      live "/", AcpDashboardLive, :index
      live "/npcs/new", AcpNpcCreatorLive, :new
      live "/npcs/:id", AcpCharacterLive, :show
      live "/npcs/:id/:tab", AcpCharacterLive, :show
      live "/social", AcpSocialLogLive, :index
      live "/moderation", AcpModerationLive, :index
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

  ## Authentication routes

  scope "/", SovereignSoulEngineWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{SovereignSoulEngineWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SovereignSoulEngineWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SovereignSoulEngineWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
