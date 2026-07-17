defmodule SovereignSoulEngineWeb.AcpDashboardLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "dashboard")
    end

    socket =
      socket
      |> assign(:page_title, "ACP — Sovereign Soul Engine")
      |> assign(:confirm_kill_id, nil)
      |> load_characters()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp load_characters(socket) do
    characters = Characters.list_characters()

    rows =
      Enum.map(characters, fn char ->
        emotional = Souls.get_emotional_state_by_character(char.id)
        soul = Souls.get_soul_profile_by_character(char.id)

        grief_arcs = Souls.list_active_grief_arcs_for_character(char.id)
        active_goals = Souls.list_active_goals_for_character(char.id)
        somatic = Souls.get_somatic_state_by_character(char.id)

        {cog_score, _stressors} =
          SovereignSoulEngine.Souls.CognitiveLoad.compute(emotional, somatic, grief_arcs, active_goals)

        %{
          character: char,
          emotional: emotional,
          soul: soul,
          cog_score: cog_score
        }
      end)

    assign(socket, :rows, rows)
  end

  @impl true
  def handle_event("confirm_kill", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirm_kill_id, id)}
  end

  @impl true
  def handle_event("cancel_kill", _params, socket) do
    {:noreply, assign(socket, :confirm_kill_id, nil)}
  end

  @impl true
  def handle_event("kill_character", %{"id" => id}, socket) do
    character = Characters.get_character!(id)
    {:ok, _} = Characters.update_character(character, %{status: "dead"})

    Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, "dashboard", {:ledger_updated, %{}})

    socket =
      socket
      |> assign(:confirm_kill_id, nil)
      |> load_characters()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ledger_updated, _}, socket), do: {:noreply, load_characters(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp emotion_dots(emotional) do
    emotions = [
      {:anger, "bg-red-500"},
      {:fear, "bg-purple-500"},
      {:stress, "bg-orange-500"},
      {:confidence, "bg-blue-500"},
      {:sadness, "bg-indigo-500"}
    ]

    Enum.map(emotions, fn {key, color} ->
      val = if emotional, do: Map.get(emotional, key) || 0, else: 0
      opacity = Float.round(val / 100, 2)
      {color, opacity, val}
    end)
  end

  defp cog_badge_color(score) when score >= 70, do: "bg-red-500"
  defp cog_badge_color(score) when score >= 40, do: "bg-yellow-500"
  defp cog_badge_color(_), do: "bg-green-500"

  defp status_badge_color("active"), do: "bg-green-500/20 text-green-400 border-green-500/30"
  defp status_badge_color("inactive"), do: "bg-gray-500/20 text-gray-400 border-gray-500/30"
  defp status_badge_color("dead"), do: "bg-red-900/40 text-red-400 border-red-500/30"
  defp status_badge_color("archived"), do: "bg-gray-700/40 text-gray-500 border-gray-600/30"
  defp status_badge_color(_), do: "bg-gray-500/20 text-gray-400 border-gray-500/30"

  defp kind_badge_color("npc"), do: "bg-amber-500/20 text-amber-400 border-amber-500/30"
  defp kind_badge_color("player"), do: "bg-blue-500/20 text-blue-400 border-blue-500/30"
  defp kind_badge_color(_), do: "bg-gray-500/20 text-gray-400 border-gray-500/30"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100">
      <%!-- Nav --%>
      <nav class="border-b border-gray-800 bg-gray-900 px-6 py-3 flex items-center gap-6">
        <span class="text-amber-400 font-bold text-sm tracking-wide">SOVEREIGN SOUL ENGINE — ACP</span>
        <div class="flex items-center gap-4 ml-4">
          <.link navigate={~p"/sse/acp"} class="text-sm text-amber-400 font-semibold border-b border-amber-400 pb-0.5">
            Dashboard
          </.link>
          <.link navigate={~p"/sse/acp/npcs/new"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
            New NPC
          </.link>
          <.link navigate={~p"/sse/acp/social"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
            Social Log
          </.link>
        </div>
      </nav>

      <div class="px-6 py-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h1 class="text-xl font-bold text-gray-100">Character Registry</h1>
            <p class="text-xs text-gray-500 mt-0.5">{length(@rows)} soul(s) in the engine</p>
          </div>
          <.link
            navigate={~p"/sse/acp/npcs/new"}
            class="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg bg-amber-500/10 border border-amber-500/30 text-amber-400 text-sm font-semibold hover:bg-amber-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="size-4" /> New NPC
          </.link>
        </div>

        <div class="rounded-xl border border-gray-800 bg-gray-900 overflow-hidden">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-gray-800 text-[10px] text-gray-500 uppercase tracking-wider">
                <th class="px-4 py-3 text-left font-semibold">Name</th>
                <th class="px-4 py-3 text-left font-semibold">Kind</th>
                <th class="px-4 py-3 text-left font-semibold">Status</th>
                <th class="px-4 py-3 text-left font-semibold">Emotions</th>
                <th class="px-4 py-3 text-left font-semibold">Cog Load</th>
                <th class="px-4 py-3 text-left font-semibold">Stamina</th>
                <th class="px-4 py-3 text-right font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-800/60">
              <%= for row <- @rows do %>
                <tr class="hover:bg-gray-800/30 transition-colors group">
                  <%!-- Name --%>
                  <td class="px-4 py-3">
                    <.link navigate={~p"/sse/acp/npcs/#{row.character.id}"} class="font-semibold text-gray-100 hover:text-amber-300 transition-colors">
                      {row.character.name}
                    </.link>
                    <div class="text-[10px] text-gray-600 font-mono">{row.character.slug}</div>
                  </td>

                  <%!-- Kind --%>
                  <td class="px-4 py-3">
                    <span class={"inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold border #{kind_badge_color(row.character.kind)}"}>
                      {row.character.kind}
                    </span>
                  </td>

                  <%!-- Status --%>
                  <td class="px-4 py-3">
                    <span class={"inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold border #{status_badge_color(row.character.status)}"}>
                      {row.character.status}
                    </span>
                  </td>

                  <%!-- Emotion sparkline dots --%>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-1.5">
                      <%= for {color, _opacity, val} <- emotion_dots(row.emotional) do %>
                        <div class="relative group/dot">
                          <div
                            class={"w-3 h-3 rounded-full #{color}"}
                            style={"opacity: #{max(0.15, val / 100)}"}
                          >
                          </div>
                        </div>
                      <% end %>
                      <span class="text-[10px] text-gray-600 ml-1">A·F·S·C·Sd</span>
                    </div>
                  </td>

                  <%!-- Cognitive Load --%>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-2">
                      <div class={"w-2.5 h-2.5 rounded-full #{cog_badge_color(row.cog_score)}"}></div>
                      <span class="text-xs text-gray-400">{row.cog_score}</span>
                    </div>
                  </td>

                  <%!-- Social Stamina --%>
                  <td class="px-4 py-3">
                    <div class="w-24">
                      <div class="h-1.5 rounded-full bg-gray-800 overflow-hidden">
                        <div
                          class="h-full rounded-full bg-blue-500 transition-all"
                          style={"width: #{if row.soul, do: row.soul.social_stamina, else: 0}%"}
                        >
                        </div>
                      </div>
                      <div class="text-[10px] text-gray-600 mt-0.5">
                        {if row.soul, do: row.soul.social_stamina, else: "—"}/{if row.soul, do: row.soul.stamina_max, else: "—"}
                      </div>
                    </div>
                  </td>

                  <%!-- Actions --%>
                  <td class="px-4 py-3 text-right">
                    <div class="flex items-center justify-end gap-2">
                      <.link
                        navigate={~p"/sse/acp/npcs/#{row.character.id}"}
                        class="text-xs px-2.5 py-1 rounded bg-gray-800 hover:bg-gray-700 text-gray-300 transition-colors"
                      >
                        Open
                      </.link>
                      <%= if row.character.status != "dead" do %>
                        <%= if @confirm_kill_id == row.character.id do %>
                          <div class="flex items-center gap-1">
                            <button
                              phx-click="kill_character"
                              phx-value-id={row.character.id}
                              class="text-xs px-2 py-1 rounded bg-red-700 hover:bg-red-600 text-white transition-colors"
                            >
                              Confirm
                            </button>
                            <button
                              phx-click="cancel_kill"
                              class="text-xs px-2 py-1 rounded bg-gray-700 text-gray-300 hover:bg-gray-600 transition-colors"
                            >
                              Cancel
                            </button>
                          </div>
                        <% else %>
                          <button
                            phx-click="confirm_kill"
                            phx-value-id={row.character.id}
                            class="text-xs px-2.5 py-1 rounded bg-red-900/30 hover:bg-red-900/50 text-red-400 border border-red-800/40 transition-colors"
                          >
                            Kill
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>

          <div :if={@rows == []} class="py-16 text-center text-gray-600">
            <.icon name="hero-user-group" class="size-10 mx-auto mb-3 opacity-40" />
            <p class="text-sm">No characters in the engine yet.</p>
            <.link navigate={~p"/sse/acp/npcs/new"} class="text-amber-400 text-sm hover:underline mt-1 inline-block">
              Create the first NPC
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
