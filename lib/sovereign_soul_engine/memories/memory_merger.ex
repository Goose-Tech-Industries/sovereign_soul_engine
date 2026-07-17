defmodule SovereignSoulEngine.Memories.MemoryMerger do
  @moduledoc """
  GenServer that merges clusters of low-importance episodic/working memories into
  a single consolidated summary row.

  How it works:
    1. After each NPC interaction, the generator casts `:consolidate` for that character.
    2. The merger finds clusters of 3+ low-importance memories sharing at least one tag.
    3. For each cluster it calls the LLM to write a single composite summary sentence.
    4. The composite is inserted as a new episodic memory with averaged importance.
    5. The source memories are marked `status: "consolidated"` so they no longer appear
       in retrieval but are preserved in the DB for audit.

  This keeps the active memory pool lean while preserving everything historically.
  """

  use GenServer
  require Logger

  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.LLM.ProviderCascade

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Schedules consolidation for `character_id` asynchronously.
  Safe to call after every interaction — it queues and runs in the background.
  """
  def consolidate_async(character_id) do
    GenServer.cast(__MODULE__, {:consolidate, character_id})
  end

  @doc """
  Runs consolidation synchronously. Mainly for tests and admin scripts.
  Returns `{:ok, merged_count}`.
  """
  def consolidate_now(character_id) do
    GenServer.call(__MODULE__, {:consolidate_sync, character_id}, 30_000)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    {:ok, %{queue: :queue.new(), processing: false}}
  end

  @impl true
  def handle_cast({:consolidate, character_id}, state) do
    new_queue = :queue.in(character_id, state.queue)
    new_state = %{state | queue: new_queue}
    if not state.processing, do: send(self(), :drain)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:consolidate_sync, character_id}, _from, state) do
    count = run_consolidation(character_id)
    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_info(:drain, state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        {:noreply, %{state | processing: false}}

      {{:value, character_id}, rest} ->
        Task.start(fn ->
          run_consolidation(character_id)
          send(__MODULE__, :drain)
        end)

        {:noreply, %{state | queue: rest, processing: true}}
    end
  end

  # --- Consolidation logic ---

  defp run_consolidation(character_id) do
    clusters = Memories.find_consolidation_candidates(character_id)

    merged_count =
      Enum.reduce(clusters, 0, fn cluster, acc ->
        case merge_cluster(cluster, character_id) do
          {:ok, _} -> acc + 1
          {:error, reason} ->
            Logger.warning("MemoryMerger failed for cluster: #{inspect(reason)}")
            acc
        end
      end)

    if merged_count > 0 do
      Logger.info("MemoryMerger: merged #{merged_count} clusters for character #{character_id}")
    end

    merged_count
  end

  defp merge_cluster(memories, character_id) do
    summaries = Enum.map_join(memories, "\n", &("- " <> &1.summary))
    avg_importance = memories |> Enum.map(& &1.importance) |> Enum.sum() |> div(length(memories))
    avg_intensity = memories |> Enum.map(& &1.emotional_intensity) |> Enum.sum() |> div(length(memories))
    avg_valence = memories |> Enum.map(& &1.valence) |> Enum.sum() |> (fn s -> s / length(memories) end).()
    all_tags = memories |> Enum.flat_map(& &1.tags) |> Enum.uniq()
    earliest_scene_id = List.first(memories) |> Map.get(:scene_id)

    prompt = """
    You are a memory archival system. The following are several minor memories that occurred between
    two characters. Merge them into ONE concise summary sentence that captures the overall pattern
    of behavior. Write in third person, past tense. Maximum 30 words. Return ONLY the summary sentence.

    Memories to merge:
    #{summaries}
    """

    case ProviderCascade.respond(%{
      system: "You are a concise archival system. Return only the summary sentence, nothing else.",
      messages: [%{role: "user", content: prompt}]
    }) do
      {:ok, response} ->
        merged_text =
          cond do
            is_binary(response) -> String.trim(response)
            is_map(response) -> response[:public_speech] || response["public_speech"] || summaries
            true -> summaries
          end

        now = DateTime.utc_now()

        case Memories.create_memory(%{
          owner_character_id: character_id,
          category: "episodic",
          summary: merged_text,
          details: %{"merged_from_count" => length(memories), "original_summaries" => Enum.map(memories, & &1.summary)},
          importance: avg_importance,
          emotional_intensity: avg_intensity,
          valence: avg_valence,
          tags: all_tags,
          status: "active",
          scene_id: earliest_scene_id,
          occurred_at: now
        }) do
          {:ok, consolidated_memory} ->
            source_ids = Enum.map(memories, & &1.id)
            Memories.mark_consolidated(source_ids, consolidated_memory.id)
            {:ok, consolidated_memory}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning("MemoryMerger LLM call failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
