import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/sovereign_soul_engine start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint, server: true
end

config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "8561"))]

# Peer-to-peer Soul Society relay (RFC-0002 §3). Read at boot so releases can
# configure peers/secret without a rebuild. Forwarding is hop-limited; an
# optional shared secret authenticates peers; a cap bounds remote-soul growth.
llm_spend_cap =
  case System.get_env("LLM_SPEND_CAP") do
    nil -> nil
    "" -> nil
    val -> String.to_integer(val)
  end

config :sovereign_soul_engine,
  relay_peers: (System.get_env("RELAY_PEERS") || "") |> String.split(",", trim: true),
  relay_max_hops: String.to_integer(System.get_env("RELAY_MAX_HOPS") || "2"),
  relay_secret: System.get_env("RELAY_SECRET"),
  max_remote_souls: String.to_integer(System.get_env("MAX_REMOTE_SOULS") || "1000"),
  moderation_blocked_terms:
    (System.get_env("MODERATION_BLOCKED_TERMS") || "") |> String.split(",", trim: true),
  llm_spend_cap: llm_spend_cap

# Error tracking — inert unless SENTRY_DSN is set. Use Req (already a dep) as
# the HTTP client instead of the default Hackney.
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  client: Sentry.ReqClient,
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!()

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :sovereign_soul_engine, SovereignSoulEngine.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # A shared relay secret is mandatory once peers are configured in production,
  # otherwise any node could relay envelopes into the cluster.
  peers = (System.get_env("RELAY_PEERS") || "") |> String.split(",", trim: true)

  if peers != [] and is_nil(System.get_env("RELAY_SECRET")) do
    raise "RELAY_SECRET is required when RELAY_PEERS is set in production"
  end

  # In production, WebSocket connections must present a valid tenant API key.
  config :sovereign_soul_engine, :require_connect_auth, true

  host = System.get_env("PHX_HOST") || "example.com"

  config :sovereign_soul_engine, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :sovereign_soul_engine, SovereignSoulEngine.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
