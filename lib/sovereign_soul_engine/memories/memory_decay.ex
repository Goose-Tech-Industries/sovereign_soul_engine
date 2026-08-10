defmodule SovereignSoulEngine.Memories.MemoryDecay do
  @moduledoc """
  Deterministic decay calculation for memories.

  Decay reduces the effective importance of a memory over time,
  modified by recall frequency, category, and the memory's intrinsic decay_rate.

  Core and wound memories are more resistant to decay.
  Frequently recalled memories retain their strength.
  """

  @category_decay_resistance %{
    core: 0.001,
    wound: 0.002,
    belief: 0.003,
    relationship: 0.01,
    episodic: 0.02,
    working: 0.05
  }

  @doc """
  Calculates the decayed importance of a memory.

  The memory map must include:
    - `:importance` (integer)
    - `:decay_rate` (float)
    - `:category` (string or atom)
    - `:recall_count` (integer)
    - `:occurred_at` (DateTime or NaiveDateTime)

  Optional:
    - `:last_recalled_at` (DateTime or NaiveDateTime) — defaults to `:occurred_at`

  Returns a map with:
    - `:original_importance` — the input importance
    - `:decayed_importance` — the effective importance after decay
    - `:decay_loss` — how much was lost
    - `:decay_percentage` — percentage of original retained
    - `:effective_decay_rate` — the applied decay rate after modifiers
  """
  @spec calculate(map(), keyword()) :: map()
  def calculate(memory, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    importance = Map.get(memory, :importance, 1)
    decay_rate = Map.get(memory, :decay_rate, 1.0)
    category = normalize_category(Map.get(memory, :category))
    recall_count = Map.get(memory, :recall_count, 0)
    last_recall = Map.get(memory, :last_recalled_at) || Map.get(memory, :occurred_at) || now

    category_resistance = Map.get(@category_decay_resistance, category, 1.0)

    # Time since last recall in days
    days_elapsed = days_between(last_recall, now)

    # Frequent recall increases resistance
    recall_resistance = 1.0 / (1.0 + :math.log(max(recall_count, 1)) / :math.log(2))

    # Effective decay rate
    effective_rate = decay_rate * category_resistance * recall_resistance

    # Exponential decay: importance * e^(-rate * days)
    # But cap at a floor of 1, never reduce to 0
    decayed =
      max(
        trunc(importance * :math.exp(-effective_rate * days_elapsed)),
        1
      )

    %{
      original_importance: importance,
      decayed_importance: decayed,
      decay_loss: importance - decayed,
      decay_percentage: Float.round(decayed / max(importance, 1) * 100, 1),
      effective_decay_rate: Float.round(effective_rate, 4)
    }
  end

  @doc """
  Calculates the new decay_rate to use for a memory after a recall event.

  Recalling a memory should slow its future decay.
  Returns a float representing the new decay_rate.
  """
  @spec adjust_decay_rate_after_recall(float(), integer()) :: float()
  def adjust_decay_rate_after_recall(current_decay_rate, recall_count) when recall_count > 0 do
    # Each recall reduces decay rate, with diminishing returns
    reduction = 1.0 / (1.0 + 0.3 * recall_count)
    max(current_decay_rate * reduction, 0.05)
  end

  def adjust_decay_rate_after_recall(current_decay_rate, _), do: current_decay_rate

  defp normalize_category(cat) when is_atom(cat), do: cat
  defp normalize_category(cat) when is_binary(cat), do: String.to_existing_atom(cat)
  defp normalize_category(_), do: :episodic

  defp days_between(dt1, dt2) do
    secs = abs(DateTime.diff(ensure_datetime(dt1), ensure_datetime(dt2)))
    secs / 86_400.0
  end

  defp ensure_datetime(%DateTime{} = dt), do: dt

  defp ensure_datetime(%NaiveDateTime{} = ndt) do
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  defp ensure_datetime(_), do: DateTime.utc_now()
end
