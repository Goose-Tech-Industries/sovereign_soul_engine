defmodule SovereignSoulEngine.Moderation do
  @moduledoc """
  World-level content moderation for autonomous output (events, gossip, posts).

  Two independent mechanisms:
    - a configurable **blocked-term** filter (`redact/1`) that scrubs text,
    - a mutable in-memory set of **muted DIDs** (`mute_did/1`).

  `screen/1` combines both and gates what enters the world ledger.
  """

  use GenServer

  @table :sse_moderation

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "The configured blocked terms (comma-separated `MODERATION_BLOCKED_TERMS`)."
  def blocked_terms do
    Application.get_env(:sovereign_soul_engine, :moderation_blocked_terms, [])
  end

  @doc "Replaces blocked terms in text with `[redacted]`."
  def redact(nil), do: nil

  def redact(text) when is_binary(text) do
    Enum.reduce(blocked_terms(), text, fn term, acc ->
      String.replace(acc, ~r/#{Regex.escape(term)}/i, "[redacted]")
    end)
  end

  def redact(other), do: other

  def mute_did(did), do: GenServer.cast(__MODULE__, {:mute, did})
  def unmute_did(did), do: GenServer.cast(__MODULE__, {:unmute, did})
  def muted?(did), do: GenServer.call(__MODULE__, {:muted?, did})

  @doc """
  Gates an event map (with `:from_did` and `:payload`). Returns `:ok` or an error
  tuple. Muted DIDs are rejected outright; otherwise the payload is checked for
  fully-blocked content.
  """
  def screen(attrs) do
    from = attrs[:from_did] || attrs["from_did"]

    cond do
      from && muted?(from) -> {:error, :muted}
      blocked_content?(attrs[:payload] || attrs["payload"] || %{}) -> {:error, :blocked_content}
      true -> :ok
    end
  end

  defp blocked_content?(payload) when is_map(payload) do
    Enum.any?(payload, fn {_k, v} -> blocked_value?(v) end)
  end

  defp blocked_content?(_), do: false

  defp blocked_value?(v) when is_binary(v) do
    redacted = redact(v)
    String.trim(redacted) in ["", "[redacted]"]
  end

  defp blocked_value?(v) when is_map(v), do: blocked_content?(v)
  defp blocked_value?(v) when is_list(v), do: Enum.any?(v, &blocked_value?/1)
  defp blocked_value?(_), do: false

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:mute, did}, state) do
    :ets.insert(@table, {did, true})
    {:noreply, state}
  end

  def handle_cast({:unmute, did}, state) do
    :ets.delete(@table, did)
    {:noreply, state}
  end

  @impl true
  def handle_call({:muted?, did}, _from, state) do
    {:reply, :ets.member(@table, did), state}
  end
end
