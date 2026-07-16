import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :sovereign_soul_engine, SovereignSoulEngine.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "sovereign_soul_engine_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost"],
  secret_key_base: "V/2fUN+OT5ALEPjXU5FCVQZ5hIwYh3Hzj1i6bMBERN63JP20YUaNmiJOdx0/xmW+",
  server: false

# In test we don't send emails
config :sovereign_soul_engine, SovereignSoulEngine.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Use FakeProvider in tests for interactive mock dialogue
config :sovereign_soul_engine, :llm_providers, [
  SovereignSoulEngine.LLM.FakeProvider
]
