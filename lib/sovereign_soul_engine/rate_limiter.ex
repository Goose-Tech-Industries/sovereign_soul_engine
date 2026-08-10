defmodule SovereignSoulEngine.RateLimiter do
  @moduledoc """
  Fixed-window per-tenant request limiter, backed by a public ETS table.
  In-memory and per-node — the right size for a single-node deploy whose
  only job is stopping runaway abuse against `/sse/api/*`, not exact
  billing-grade accounting (that's `Tenants.llm_call_count`, a persisted
  DB counter). Resets on deploy; that's an accepted tradeoff, not a gap.
  """

  use GenServer

  @table :sse_rate_limits
  @window_seconds 60
  @sweep_interval :timer.minutes(5)
  # Windows older than this many buckets are safe to drop.
  @stale_after_windows 2

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Increments this tenant's counter for the current window and checks it
  against `limit_per_minute`. Returns `:ok` or `{:error, :rate_limited, retry_after_seconds}`.
  """
  def check(tenant_id, limit_per_minute) do
    now = System.system_time(:second)
    window = div(now, @window_seconds)
    key = {tenant_id, window}
    count = :ets.update_counter(@table, key, {2, 1}, {key, 0})

    if count > limit_per_minute do
      retry_after = @window_seconds - rem(now, @window_seconds)
      {:error, :rate_limited, retry_after}
    else
      :ok
    end
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff = div(System.system_time(:second), @window_seconds) - @stale_after_windows

    :ets.select_delete(@table, [
      {{{:_, :"$1"}, :_}, [{:<, :"$1", cutoff}], [true]}
    ])

    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)
end
