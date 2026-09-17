defmodule SovereignSoulEngineWeb.Presence do
  use Phoenix.Presence,
    otp_app: :sovereign_soul_engine,
    pubsub_server: SovereignSoulEngine.PubSub
end
