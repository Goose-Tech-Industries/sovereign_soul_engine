defmodule SovereignSoulEngineWeb.MemoryVaultLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Characters

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Memory Vault")
      |> assign(:characters, Characters.list_characters())
      |> assign(:memories, Memories.list_memories() |> Enum.take(50))
      |> assign(:filter_category, nil)
      |> assign(:filter_character_id, nil)
      |> assign(:categories, ~w(working episodic relationship core wound belief))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "ledger")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:ledger_updated, _entry}, socket) do
    memories = fetch_memories(socket)
    {:noreply, assign(socket, :memories, memories)}
  end

  def handle_info({:memory_created, _mem}, socket) do
    memories = fetch_memories(socket)
    {:noreply, assign(socket, :memories, memories)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter", %{"category" => cat, "character_id" => char_id}, socket) do
    cat = if cat == "", do: nil, else: cat
    char_id = if char_id == "", do: nil, else: char_id

    socket =
      socket
      |> assign(:filter_category, cat)
      |> assign(:filter_character_id, char_id)

    memories = fetch_memories(socket)
    {:noreply, assign(socket, :memories, memories)}
  end

  defp fetch_memories(socket) do
    cat = socket.assigns.filter_category
    char_id = socket.assigns.filter_character_id

    cond do
      cat && char_id ->
        Memories.list_memories_by_category(char_id, cat)

      char_id ->
        Memories.list_memories_for_character(char_id) |> Enum.take(50)

      true ->
        Memories.list_memories() |> Enum.take(50)
    end
  end

  defp character_name(characters, id) do
    char = Enum.find(characters, &(&1.id == id))
    if char, do: char.name, else: nil
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div>
          <.link
            navigate={~p"/sse"}
            class="text-sm text-base-content/60 hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left" class="size-4 inline" /> Dashboard
          </.link>
          <h1 class="text-2xl font-bold text-base-content mt-1">Memory Vault</h1>
          
          <p class="text-sm text-base-content/50 mt-0.5">Browse and filter all character memories</p>
        </div>
         <%!-- Filters --%>
        <form phx-change="filter" id="memory-filter-form" class="flex items-center gap-3">
          <select
            name="character_id"
            id="memory-char-filter"
            class="text-sm rounded-lg border border-base-300 bg-base-200 px-3 py-1.5 text-base-content"
          >
            <option value="">All Characters</option>
            
            <%= for char <- @characters do %>
              <option value={char.id} selected={@filter_character_id == char.id}>{char.name}</option>
            <% end %>
          </select>
          <select
            name="category"
            id="memory-cat-filter"
            class="text-sm rounded-lg border border-base-300 bg-base-200 px-3 py-1.5 text-base-content"
          >
            <option value="">All Categories</option>
            
            <%= for cat <- @categories do %>
              <option value={cat} selected={@filter_category == cat}>{String.capitalize(cat)}</option>
            <% end %>
          </select>
        </form>
         <%!-- Memory Grid --%>
        <div :if={@memories == []} class="p-8 text-center rounded-xl border border-base-300">
          <p class="text-base-content/50">No memories found. Events in scenes generate memories.</p>
        </div>
        
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <%= for mem <- @memories do %>
            <div class="p-3 rounded-lg border border-base-300 bg-base-200/30 hover:bg-base-200/50 transition-colors">
              <div class="flex items-start justify-between gap-2 mb-2">
                <p class="text-sm font-medium text-base-content leading-snug">{mem.summary}</p>
                
                <span class={[
                  "shrink-0 text-xs px-1.5 py-0.5 rounded font-medium",
                  cat_badge(mem.category)
                ]}>
                  {mem.category}
                </span>
              </div>
              
              <div class="space-y-1">
                <div class="flex items-center gap-3 text-xs text-base-content/50">
                  <span>
                    Importance: <span class="text-base-content/80">{mem.importance || 0}</span>
                  </span>
                  <span>
                    Intensity:
                    <span class="text-base-content/80">{mem.emotional_intensity || 0}</span>
                  </span>
                </div>
                
                <div class="flex items-center gap-3 text-xs text-base-content/50">
                  <span>
                    Valence: <span class="text-base-content/80">{format_valence(mem.valence)}</span>
                  </span>
                  <span>
                    Recall: <span class="text-base-content/80">{mem.recall_count || 0}</span>
                  </span>
                </div>
                
                <div class="flex items-center gap-3 text-xs">
                  <span :if={mem.is_resolved} class="text-emerald-400">Resolved</span>
                  <span :if={!mem.is_resolved} class="text-amber-400">Unresolved</span>
                  <span class="text-base-content/40">Decay: {format_decay(mem.decay_rate)}</span>
                </div>
                
                <div class="flex items-center gap-2 text-xs text-base-content/50">
                  <span :if={
                    mem.owner_character_id && character_name(@characters, mem.owner_character_id)
                  }>
                    Owner: {character_name(@characters, mem.owner_character_id)}
                  </span>
                  <span :if={
                    mem.subject_character_id && character_name(@characters, mem.subject_character_id)
                  }>
                    · Subject: {character_name(@characters, mem.subject_character_id)}
                  </span>
                </div>
                
                <div :if={mem.tags && length(mem.tags) > 0} class="flex flex-wrap gap-1 mt-1">
                  <%= for tag <- Enum.take(mem.tags, 5) do %>
                    <span class="text-[10px] px-1.5 py-0.5 rounded bg-base-300 text-base-content/60">
                      {tag}
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp cat_badge("core"), do: "bg-red-500/15 text-red-300"
  defp cat_badge("wound"), do: "bg-red-500/20 text-red-400"
  defp cat_badge("belief"), do: "bg-purple-500/15 text-purple-300"
  defp cat_badge("relationship"), do: "bg-blue-500/15 text-blue-300"
  defp cat_badge("episodic"), do: "bg-emerald-500/15 text-emerald-300"
  defp cat_badge("working"), do: "bg-amber-500/15 text-amber-300"
  defp cat_badge(_), do: "bg-base-300 text-base-content/60"

  defp format_valence(nil), do: "0.00"
  defp format_valence(v) when is_number(v), do: :erlang.float_to_binary(v / 1, decimals: 2)
  defp format_valence(_), do: "0.00"

  defp format_decay(nil), do: "1.0"
  defp format_decay(v) when is_number(v), do: :erlang.float_to_binary(v / 1, decimals: 1)
  defp format_decay(_), do: "1.0"
end
