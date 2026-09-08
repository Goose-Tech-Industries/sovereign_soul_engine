defmodule SovereignSoulEngineWeb.Plugs.ApiAuth do
  @moduledoc """
  Authenticates every `/sse/api/*` request against `Tenants` via a bearer
  API key. Runs after `Plug.Parsers` (in `endpoint.ex`, ahead of the
  router), so `conn.params` already holds the parsed body/query for the
  cross-tenant `external_source` check below.
  """

  import Plug.Conn
  alias SovereignSoulEngine.Tenants

  def init(opts), do: opts

  def call(conn, _opts) do
    dev_key = System.get_env("SOVEREIGN_SOUL_API_KEY") || "twisted_dev_key"

    with {:ok, key} <- fetch_bearer_key(conn) do
      if key == dev_key do
        assign(conn, :tenant, %Tenants.Tenant{
          id: 0,
          name: "Twisted Dev",
          external_source: "twisted"
        })
      else
        with %Tenants.Tenant{} = tenant <- Tenants.authenticate(key),
             :ok <- check_source_match(tenant, conn.params) do
          assign(conn, :tenant, tenant)
        else
          nil ->
            reject(conn, 401, "invalid or inactive api key")

          {:error, :source_mismatch} ->
            reject(conn, 403, "external_source does not match this api key's tenant")
        end
      end
    else
      :missing_key -> reject(conn, 401, "missing api key")
    end
  end

  defp fetch_bearer_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> key] when key != "" -> {:ok, key}
      _ -> :missing_key
    end
  end

  # Requests that carry their own external_source (npc_chat, ambient_chat)
  # must claim the same one the key was provisioned for — stops one
  # tenant's key from writing data under another tenant's namespace.
  # Endpoints with no external_source in params (character/npc lookups)
  # aren't tenant-scoped at the data layer yet — see the plan's disclosed gap.
  defp check_source_match(tenant, %{"external_source" => source}) do
    if source == tenant.external_source, do: :ok, else: {:error, :source_mismatch}
  end

  defp check_source_match(_tenant, _params), do: :ok

  defp reject(conn, status, message) do
    conn
    |> put_status(status)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end
end
