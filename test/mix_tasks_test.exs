defmodule SovereignSoulEngine.MixTasksTest do
  use SovereignSoulEngine.DataCase, async: true

  import ExUnit.CaptureIO

  alias SovereignSoulEngine.{Tenants, Repo}
  alias SovereignSoulEngine.Tenants.Tenant

  setup do
    Mix.Task.clear()
    :ok
  end

  test "create_tenant provisions a tenant and prints the key once" do
    source = "task_create_#{System.unique_integer([:positive])}"

    output =
      capture_io(fn ->
        Mix.Tasks.Sse.CreateTenant.run(["Task Tenant", source, "120"])
      end)

    tenant = Repo.get_by!(Tenant, external_source: source)
    assert tenant.name == "Task Tenant"
    assert tenant.rate_limit_per_minute == 120
    assert output =~ "Tenant created: Task Tenant"
    assert output =~ "API key (save this now"
    assert output =~ tenant.api_key_prefix
  end

  test "create_tenant uses the default rate limit" do
    source = "task_default_#{System.unique_integer([:positive])}"

    capture_io(fn ->
      Mix.Tasks.Sse.CreateTenant.run(["Default Tenant", source])
    end)

    assert Repo.get_by!(Tenant, external_source: source).rate_limit_per_minute == 60
  end

  test "create_tenant rejects invalid argument counts" do
    assert_raise Mix.Error, ~r/usage: mix sse.create_tenant/, fn ->
      Mix.Tasks.Sse.CreateTenant.run([])
    end

    assert_raise Mix.Error, ~r/usage: mix sse.create_tenant/, fn ->
      Mix.Tasks.Sse.CreateTenant.run(["only-name"])
    end
  end

  test "create_tenant rejects a non-numeric rate limit" do
    assert_raise ArgumentError, fn ->
      Mix.Tasks.Sse.CreateTenant.run(["Tenant", "bad-rate", "not-a-number"])
    end
  end

  test "set_byok reports an unknown tenant without touching providers" do
    assert_raise Mix.Error, ~r/no tenant with external_source/, fn ->
      Mix.Tasks.Sse.SetByok.run(["missing-source", "openai", "test-key"])
    end
  end

  test "set_byok rejects an unknown provider without a network call" do
    source = "task_byok_#{System.unique_integer([:positive])}"
    {:ok, _tenant, _key} = Tenants.create_tenant("BYOK Tenant", source)

    assert_raise Mix.Error, ~r/unknown provider/, fn ->
      Mix.Tasks.Sse.SetByok.run([source, "unknown", "test-key"])
    end
  end

  test "set_byok validates its argument count" do
    assert_raise Mix.Error, ~r/usage: mix sse.set_byok/, fn ->
      Mix.Tasks.Sse.SetByok.run(["source", "provider"])
    end
  end

  test "clear_byok clears an existing tenant and reports the result" do
    source = "task_clear_#{System.unique_integer([:positive])}"
    {:ok, tenant, _key} = Tenants.create_tenant("Clear Tenant", source)
    encrypted = Tenants.encrypt_byok("old-secret")

    {:ok, configured} =
      tenant
      |> Tenant.byok_changeset(%{
        byok_provider: "openai",
        byok_api_key_encrypted: encrypted
      })
      |> Repo.update()

    output =
      capture_io(fn ->
        Mix.Tasks.Sse.ClearByok.run([source])
      end)

    cleared = Repo.get!(Tenant, configured.id)
    assert cleared.byok_provider == nil
    assert cleared.byok_api_key_encrypted == nil
    assert output =~ "BYOK cleared for Clear Tenant"
  end

  test "clear_byok reports an unknown tenant" do
    assert_raise Mix.Error, ~r/no tenant with external_source/, fn ->
      Mix.Tasks.Sse.ClearByok.run(["missing-source"])
    end
  end

  test "clear_byok validates its argument count" do
    assert_raise Mix.Error, ~r/usage: mix sse.clear_byok/, fn ->
      Mix.Tasks.Sse.ClearByok.run([])
    end
  end
end
