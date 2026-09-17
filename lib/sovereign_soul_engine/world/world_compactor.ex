defmodule SovereignSoulEngine.World.WorldCompactor do
  @moduledoc """
  Rolls old `world_events` into a single `world_summary` row and marks the raw
  events compacted (RFC-0002 §7). The anti-bloat counterpart to `MemoryMerger`.

  Summarization and deletion are deliberately separated: this module summarizes;
  raw rows are dropped later via native partition-drop (a migration concern),
  not row-by-row here.
  """

  import Ecto.Query, warn: false

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.World
  alias SovereignSoulEngine.World.WorldEvent

  @default_window_days 30

  @doc """
  Compacts events older than `before` (default: 30 days ago). Returns the number
  of events compacted.
  """
  @spec compact(keyword()) :: non_neg_integer()
  def compact(opts \\ []) do
    before =
      Keyword.get(
        opts,
        :before,
        DateTime.add(DateTime.utc_now(), -@default_window_days * 24 * 3600, :second)
      )

    events = list_compactable(before)

    if events == [] do
      0
    else
      case World.append_event(build_summary(events, before)) do
        {:ok, _summary} ->
          ids = Enum.map(events, & &1.id)
          mark_compacted(ids)
          length(events)

        {:error, _} ->
          0
      end
    end
  end

  defp list_compactable(before) do
    from(e in WorldEvent,
      where: e.compacted == false and e.inserted_at < ^before,
      order_by: [asc: e.inserted_at]
    )
    |> Repo.all()
  end

  defp build_summary(events, before) do
    kind_counts =
      events
      |> Enum.frequencies_by(& &1.kind)
      |> Enum.sort()
      |> Enum.map_join(", ", fn {kind, n} -> "#{n} #{kind}" end)

    %{
      kind: "world_summary",
      from_did: nil,
      to_did: nil,
      payload: %{
        "summarized_count" => length(events),
        "kinds" => kind_counts,
        "window_start" => DateTime.to_iso8601(before)
      },
      signature: nil,
      retained_until: nil
    }
  end

  defp mark_compacted(ids) do
    from(e in WorldEvent, where: e.id in ^ids)
    |> Repo.update_all(set: [compacted: true])
  end
end
