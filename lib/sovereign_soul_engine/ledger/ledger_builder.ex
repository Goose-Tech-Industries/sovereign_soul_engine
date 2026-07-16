defmodule SovereignSoulEngine.Ledger.LedgerBuilder do
  @moduledoc """
  Constructs immutable ledger entry changesets from state changes.

  Each entry documents:
    - What changed
    - Why it changed
    - The before state
    - The delta applied
    - The after state
    - The rule/reason applied
    - Correlation ID for linking related entries

  All entries produced are insert-only (no updates).
  """

  alias SovereignSoulEngine.Ledger.SoulLedger

  @doc """
  Builds a changeset for an emotion change ledger entry.
  """
  @spec build_emotion_change_entry(keyword()) :: Ecto.Changeset.t()
  def build_emotion_change_entry(opts) do
    before_state = Keyword.get(opts, :before_state, %{})
    after_state = Keyword.get(opts, :after_state, %{})
    delta = compute_delta(before_state, after_state)

    build_base(opts)
    |> Map.merge(%{
      entry_type: "emotion_change",
      source: "EmotionEngine",
      label: "Emotional State Change",
      summary: Keyword.get(opts, :summary, "Emotional state updated"),
      before_state: before_state,
      delta: delta,
      after_state: after_state,
      reason: Keyword.get(opts, :reason, "")
    })
    |> then(&SoulLedger.changeset(%SoulLedger{}, Map.put(&1, :character_id, opts[:character_id])))
  end

  @doc """
  Builds a changeset for a relationship change ledger entry.
  """
  @spec build_relationship_change_entry(keyword()) :: Ecto.Changeset.t()
  def build_relationship_change_entry(opts) do
    before_state = Keyword.get(opts, :before_state, %{})
    after_state = Keyword.get(opts, :after_state, %{})
    delta = compute_delta(before_state, after_state)

    build_base(opts)
    |> Map.merge(%{
      entry_type: "relationship_change",
      source: "RelationshipEngine",
      label: "Relationship Change",
      summary: Keyword.get(opts, :summary, "Relationship updated"),
      before_state: before_state,
      delta: delta,
      after_state: after_state,
      reason: Keyword.get(opts, :reason, "")
    })
    |> then(fn attrs ->
      SoulLedger.changeset(
        %SoulLedger{},
        Map.merge(attrs, %{
          character_id: opts[:character_id],
          relationship_id: opts[:relationship_id]
        })
      )
    end)
  end

  @doc """
  Builds a changeset for a memory creation ledger entry.
  """
  @spec build_memory_entry(keyword()) :: Ecto.Changeset.t()
  def build_memory_entry(opts) do
    build_base(opts)
    |> Map.merge(%{
      entry_type: Keyword.get(opts, :entry_type, "memory_created") |> to_string(),
      source: "MemorySystem",
      label: "Memory Entry",
      summary: Keyword.get(opts, :summary, "Memory recorded"),
      before_state: %{},
      delta: Keyword.get(opts, :delta, %{}),
      after_state: Keyword.get(opts, :after_state, Keyword.get(opts, :delta, %{})),
      reason: Keyword.get(opts, :reason, "")
    })
    |> then(fn attrs ->
      SoulLedger.changeset(
        %SoulLedger{},
        Map.merge(attrs, %{
          character_id: opts[:character_id],
          memory_id: opts[:memory_id]
        })
      )
    end)
  end

  @doc """
  Builds a changeset for an action resolution ledger entry.
  """
  @spec build_action_entry(keyword()) :: Ecto.Changeset.t()
  def build_action_entry(opts) do
    build_base(opts)
    |> Map.merge(%{
      entry_type: Keyword.get(opts, :entry_type, :action_proposed) |> to_string(),
      source: "ActionPolicy",
      label: "Action Resolution",
      summary: Keyword.get(opts, :summary, "Action processed"),
      before_state: Keyword.get(opts, :before_state, %{}),
      delta: Keyword.get(opts, :delta, %{}),
      after_state: Keyword.get(opts, :after_state, %{}),
      reason: Keyword.get(opts, :reason, "")
    })
    |> then(&SoulLedger.changeset(%SoulLedger{}, Map.put(&1, :character_id, opts[:character_id])))
  end

  @doc """
  Builds a changeset for a general event ledger entry.
  """
  @spec build_event_entry(keyword()) :: Ecto.Changeset.t()
  def build_event_entry(opts) do
    build_base(opts)
    |> Map.merge(%{
      entry_type: Keyword.get(opts, :entry_type, :event_injected) |> to_string(),
      source: Keyword.get(opts, :source, "event"),
      label: Keyword.get(opts, :label, "Event"),
      summary: Keyword.get(opts, :summary, "Event recorded"),
      before_state: %{},
      delta: Keyword.get(opts, :delta, %{}),
      after_state: Keyword.get(opts, :after_state, Keyword.get(opts, :delta, %{})),
      reason: Keyword.get(opts, :reason, "")
    })
    |> then(fn attrs ->
      SoulLedger.changeset(
        %SoulLedger{},
        Map.merge(attrs, %{
          character_id: opts[:character_id],
          event_id: opts[:event_id]
        })
      )
    end)
  end

  @doc """
  Builds a base ledger entry without committing to a specific entry type.
  Useful for custom entry types.
  """
  @spec build_custom_entry(keyword()) :: Ecto.Changeset.t()
  def build_custom_entry(opts) do
    SoulLedger.changeset(%SoulLedger{}, %{
      character_id: opts[:character_id],
      scene_id: opts[:scene_id],
      event_id: opts[:event_id],
      relationship_id: opts[:relationship_id],
      memory_id: opts[:memory_id],
      entry_type: to_string(opts[:entry_type] || "custom"),
      source: opts[:source] || "system",
      label: opts[:label] || "Custom Entry",
      summary: opts[:summary] || "",
      before_state: opts[:before_state] || %{},
      delta: opts[:delta] || %{},
      after_state: opts[:after_state] || %{},
      reason: opts[:reason] || "",
      tags: opts[:tags] || [],
      correlation_id: opts[:correlation_id]
    })
  end

  defp build_base(opts) do
    %{
      scene_id: opts[:scene_id],
      event_id: opts[:event_id],
      correlation_id: opts[:correlation_id],
      tags: opts[:tags] || []
    }
  end

  defp compute_delta(before_state, after_state) do
    Map.keys(after_state)
    |> Enum.filter(&Map.has_key?(before_state, &1))
    |> Enum.map(fn key ->
      {key, Map.get(after_state, key) - Map.get(before_state, key, 0)}
    end)
    |> Enum.into(%{})
  end
end
