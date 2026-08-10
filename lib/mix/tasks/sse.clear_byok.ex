defmodule Mix.Tasks.Sse.ClearByok do
  @moduledoc """
  Removes a tenant's BYOK configuration, reverting them to the operator's
  own provider cascade.

      mix sse.clear_byok planet_mado
  """
  @shortdoc "Clears a tenant's BYOK configuration"

  use Mix.Task

  alias SovereignSoulEngine.Tenants

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [external_source] -> clear(external_source)
      _ -> Mix.raise("usage: mix sse.clear_byok <external_source>")
    end
  end

  defp clear(external_source) do
    case Tenants.list_tenants() |> Enum.find(&(&1.external_source == external_source)) do
      nil ->
        Mix.raise("no tenant with external_source #{inspect(external_source)}")

      tenant ->
        {:ok, updated} = Tenants.clear_byok(tenant)
        Mix.shell().info("BYOK cleared for #{updated.name} — back to the operator's cascade.")
    end
  end
end
