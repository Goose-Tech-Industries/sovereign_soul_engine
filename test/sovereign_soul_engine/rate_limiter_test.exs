defmodule SovereignSoulEngine.RateLimiterTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.RateLimiter

  setup do
    unless Process.whereis(RateLimiter) do
      start_supervised!(RateLimiter)
    end

    :ok
  end

  test "allows requests under the limit" do
    tenant = Ecto.UUID.generate()

    assert :ok = RateLimiter.check(tenant, 1_000_000)
    assert :ok = RateLimiter.check(tenant, 1_000_000)
  end

  test "rate limits when the limit is exceeded" do
    tenant = Ecto.UUID.generate()

    assert :ok = RateLimiter.check(tenant, 1)
    assert {:error, :rate_limited, retry_after} = RateLimiter.check(tenant, 1)
    assert is_integer(retry_after)
    assert retry_after > 0
    assert retry_after <= 60
  end

  test "rate limits immediately when the limit is zero" do
    tenant = Ecto.UUID.generate()

    assert {:error, :rate_limited, _} = RateLimiter.check(tenant, 0)
  end

  test "tenants are counted independently" do
    a = Ecto.UUID.generate()
    b = Ecto.UUID.generate()

    assert :ok = RateLimiter.check(a, 1)
    assert :ok = RateLimiter.check(b, 1)
  end
end
