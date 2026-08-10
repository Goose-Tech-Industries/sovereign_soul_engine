defmodule Mix.Tasks.Sse.CreateTenant do
  @moduledoc """
  Provisions a new external API tenant and prints its plaintext key once.

      mix sse.create_tenant "Planet Mado" planet_mado
      mix sse.create_tenant "Planet Mado" planet_mado 120

  The third, optional argument is the per-minute rate limit (default 60).
  There is no admin UI for this yet (see the API keys + rate limiting plan) —
  this task is the only way to mint or rotate a tenant's key.
  """
  @shortdoc "Creates a new external API tenant and prints its key once"

  use Mix.Task

  alias SovereignSoulEngine.Tenants

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [name, external_source] -> create(name, external_source, 60)
      [name, external_source, rate_limit] -> create(name, external_source, String.to_integer(rate_limit))
      _ -> Mix.raise("usage: mix sse.create_tenant \"<name>\" <external_source> [rate_limit_per_minute]")
    end
  end

  defp create(name, external_source, rate_limit) do
    case Tenants.create_tenant(name, external_source, rate_limit) do
      {:ok, tenant, plaintext_key} ->
        Mix.shell().info("""

        Tenant created: #{tenant.name} (external_source: #{tenant.external_source})
        Rate limit: #{tenant.rate_limit_per_minute}/min

        API key (save this now — it cannot be shown again):

          #{plaintext_key}

        """)

      {:error, changeset} ->
        Mix.raise("Could not create tenant: #{inspect(changeset.errors)}")
    end
  end
end
