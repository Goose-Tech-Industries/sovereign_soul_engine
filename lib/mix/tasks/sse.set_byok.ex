defmodule Mix.Tasks.Sse.SetByok do
  @moduledoc """
  Configures a tenant's own LLM provider key (bring-your-own-key). The key
  is test-called against the real provider before anything is saved — a
  broken key is rejected here, not discovered on a real player's first
  message.

      mix sse.set_byok planet_mado anthropic sk-ant-...

  Provider must be one of: anthropic, openai, deepseek, xai, gemini.
  """
  @shortdoc "Configures a tenant's own LLM provider key"

  use Mix.Task

  alias SovereignSoulEngine.Tenants

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [external_source, provider, api_key] -> set(external_source, provider, api_key)
      _ -> Mix.raise("usage: mix sse.set_byok <external_source> <provider> <api_key>")
    end
  end

  defp set(external_source, provider, api_key) do
    case Tenants.list_tenants() |> Enum.find(&(&1.external_source == external_source)) do
      nil ->
        Mix.raise("no tenant with external_source #{inspect(external_source)}")

      tenant ->
        case Tenants.set_byok(tenant, provider, api_key) do
          {:ok, updated} ->
            Mix.shell().info(
              "BYOK configured for #{updated.name}: #{updated.byok_provider} (verified with a live test call)."
            )

          {:error, :invalid_provider} ->
            Mix.raise("unknown provider #{inspect(provider)} — must be one of: anthropic, openai, deepseek, xai, gemini")

          {:error, :key_test_failed, reason} ->
            Mix.raise("key rejected — test call to #{provider} failed: #{inspect(reason)}")

          {:error, changeset} ->
            Mix.raise("could not save: #{inspect(changeset.errors)}")
        end
    end
  end
end
