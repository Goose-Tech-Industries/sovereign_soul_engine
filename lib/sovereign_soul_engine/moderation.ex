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

  @doc "The configured blocked terms (static config plus runtime additions)."
  def blocked_terms do
    static = Application.get_env(:sovereign_soul_engine, :moderation_blocked_terms, [])
    dynamic = list_dynamic_blocked_terms()
    Enum.uniq(static ++ dynamic)
  end

  @doc "Adds a dynamic blocked term at runtime."
  def add_blocked_term(term) when is_binary(term) do
    term = String.trim(term)

    if term != "" do
      GenServer.call(__MODULE__, {:add_blocked_term, term})
    else
      :ok
    end
  end

  @doc "Removes a dynamic blocked term at runtime."
  def remove_blocked_term(term) when is_binary(term) do
    GenServer.call(__MODULE__, {:remove_blocked_term, String.trim(term)})
  end

  @doc "Lists all dynamically registered blocked terms."
  def list_dynamic_blocked_terms do
    if :ets.info(@table) != :undefined do
      :ets.tab2list(@table)
      |> Enum.filter(fn
        {{:blocked_term, _}, true} -> true
        _ -> false
      end)
      |> Enum.map(fn {{:blocked_term, term}, true} -> term end)
    else
      []
    end
  end

  @doc "Lists all currently muted DIDs."
  def list_muted_dids do
    if :ets.info(@table) != :undefined do
      :ets.tab2list(@table)
      |> Enum.filter(fn
        {did, true} when is_binary(did) -> true
        _ -> false
      end)
      |> Enum.map(fn {did, true} -> did end)
    else
      []
    end
  end

  @doc "Returns the active maturity rating preset: 'teen' | 'mature' | 'adult'."
  def get_maturity_rating do
    if :ets.info(@table) != :undefined do
      case :ets.lookup(@table, :maturity_rating) do
        [{:maturity_rating, rating}] -> rating
        _ -> "mature"
      end
    else
      "mature"
    end
  end

  @doc "Sets the active maturity rating preset: 'teen' | 'mature' | 'adult'."
  def set_maturity_rating(rating) when rating in ["teen", "mature", "adult"] do
    GenServer.call(__MODULE__, {:set_maturity_rating, rating})
  end

  @doc "Replaces blocked terms in text with `[redacted]`."
  def redact(nil), do: nil

  def redact(text) when is_binary(text) do
    Enum.reduce(blocked_terms(), text, fn term, acc ->
      String.replace(acc, ~r/#{Regex.escape(term)}/i, "[redacted]")
    end)
  end

  def redact(other), do: other

  def mute_did(did), do: GenServer.call(__MODULE__, {:mute, did})
  def unmute_did(did), do: GenServer.call(__MODULE__, {:unmute, did})
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
  def handle_call({:mute, did}, _from, state) do
    :ets.insert(@table, {did, true})
    {:reply, :ok, state}
  end

  def handle_call({:unmute, did}, _from, state) do
    :ets.delete(@table, did)
    {:reply, :ok, state}
  end

  def handle_call({:muted?, did}, _from, state) do
    {:reply, :ets.member(@table, did), state}
  end

  def handle_call({:add_blocked_term, term}, _from, state) do
    :ets.insert(@table, {{:blocked_term, term}, true})
    {:reply, :ok, state}
  end

  def handle_call({:remove_blocked_term, term}, _from, state) do
    :ets.delete(@table, {:blocked_term, term})
    {:reply, :ok, state}
  end

  def handle_call({:set_maturity_rating, rating}, _from, state) do
    :ets.insert(@table, {:maturity_rating, rating})
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
