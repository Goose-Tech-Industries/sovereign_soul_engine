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

  # Public external access for Polsia / Twitter / RSS, Telegram Webhooks, Alexa, and Portable Souls
  scope "/api", SovereignSoulEngineWeb.Api do
    post "/webhooks/telegram", TelegramWebhookController, :webhook
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
    post "/webhooks/telegram", TelegramWebhookController, :webhook
    post "/alexa", AlexaController, :handle
  end

  scope "/", SovereignSoulEngineWeb do
    pipe_through :browser

    live "/", LandingLive, :index
    get "/chat", PageController, :home
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
