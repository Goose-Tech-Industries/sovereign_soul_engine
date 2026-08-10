defmodule SovereignSoulEngineWeb.Plugs.RateLimit do
  @moduledoc "Runs after ApiAuth — enforces the authenticated tenant's per-minute request limit."

  import Plug.Conn
  alias SovereignSoulEngine.RateLimiter

  def init(opts), do: opts

  def call(%{assigns: %{tenant: tenant}} = conn, _opts) do
    case RateLimiter.check(tenant.id, tenant.rate_limit_per_minute) do
      :ok ->
        conn

      {:error, :rate_limited, retry_after} ->
        conn
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_status(429)
        |> Phoenix.Controller.json(%{error: "rate limited", retry_after_seconds: retry_after})
        |> halt()
    end
  end
end
