defmodule SovereignSoulEngine.TenantsUsageTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Tenants

  test "total_llm_calls/0 sums across tenants" do
    assert Tenants.total_llm_calls() == 0

    {:ok, tenant, _key} = Tenants.create_tenant("Usage", "usage_test")
    Tenants.record_llm_call(tenant)
    Tenants.record_llm_call(tenant)

    assert Tenants.total_llm_calls() == 2
  end

  test "over_spend_cap?/0 respects the configured cap" do
    Application.put_env(:sovereign_soul_engine, :llm_spend_cap, 1)
    on_exit(fn -> Application.delete_env(:sovereign_soul_engine, :llm_spend_cap) end)

    {:ok, tenant, _key} = Tenants.create_tenant("Cap", "cap_test")

    refute Tenants.over_spend_cap?()
    Tenants.record_llm_call(tenant)
    assert Tenants.over_spend_cap?()
  end

  test "over_spend_cap?/0 is false when no cap is configured" do
    assert Tenants.over_spend_cap?() == false
  end

  test "usage/0 returns a summary" do
    usage = Tenants.usage()

    assert Map.has_key?(usage, :total_calls)
    assert Map.has_key?(usage, :cap)
    assert Map.has_key?(usage, :over_cap)
  end
end
