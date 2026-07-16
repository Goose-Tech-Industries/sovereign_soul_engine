defmodule SovereignSoulEngine.Repo do
  use Ecto.Repo,
    otp_app: :sovereign_soul_engine,
    adapter: Ecto.Adapters.Postgres
end
