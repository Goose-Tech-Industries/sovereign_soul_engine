defmodule SovereignSoulEngineWeb.AcpSocialLogLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Social.NPCScheduler
  alias Phoenix.LiveView.JS

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scenes:list_updates")
    end

    socket =
      socket
      |> assign(:page_title, "Social Log — ACP")
      |> load_scenes()

    # Preselect scene if an ID was passed in params on mount
    socket =
      case Map.get(params, "id") do
        nil -> select_first_scene(socket)
        id -> select_scene_by_id(socket, id)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case Map.get(params, "id") do
        nil -> select_first_scene(socket)
        id -> select_scene_by_id(socket, id)
      end

    {:noreply, socket}
  end

  defp load_scenes(socket) do
    scenes = Scenes.list_autonomous_scenes(limit: 50)
    assign(socket, :scenes, scenes)
  end

  defp select_first_scene(socket) do
    case socket.assigns.scenes do
      [first | _] -> select_scene(socket, first)
      _ -> assign_empty_scene(socket)
    end
  end

  defp select_scene_by_id(socket, id) do
    case Enum.find(socket.assigns.scenes, &(&1.id == id)) do
      nil -> assign_empty_scene(socket)
      scene -> select_scene(socket, scene)
    end
  end

  defp select_scene(socket, scene) do
    scene = SovereignSoulEngine.Repo.preload(scene, [participants: :character], force: true)
    messages = Scenes.list_messages(scene.id)

    if connected?(socket) do
      if old_scene = socket.assigns[:selected_scene] do
        Phoenix.PubSub.unsubscribe(SovereignSoulEngine.PubSub, "scene:#{old_scene.id}")
      end
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{scene.id}")
    end

    socket
    |> assign(:selected_scene, scene)
    |> assign(:messages, messages)
  end

  defp assign_empty_scene(socket) do
    socket
    |> assign(:selected_scene, nil)
    |> assign(:messages, [])
  end

  @impl true
  def handle_event("trigger_tick", _params, socket) do
    NPCScheduler.trigger_tick()
    # Give the tick a brief moment to run, then reload
    :timer.sleep(1000)

    socket =
      socket
      |> load_scenes()
      |> select_first_scene()

    {:noreply, socket}
  end

  @impl true
  def handle_info({:scenes_updated, _}, socket) do
    {:noreply, load_scenes(socket)}
  end

  @impl true
  def handle_info({:new_message, _msg}, socket) do
    if scene = socket.assigns.selected_scene do
      {:noreply, assign(socket, :messages, Scenes.list_messages(scene.id))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 flex flex-col h-screen">
      <%!-- Nav --%>
      <nav class="border-b border-gray-800 bg-gray-900 px-6 py-3 flex items-center justify-between shrink-0">
        <div class="flex items-center gap-6">
          <span class="text-amber-400 font-bold text-sm tracking-wide">SOVEREIGN SOUL ENGINE — ACP</span>
          <div class="flex items-center gap-4 ml-4">
            <.link navigate={~p"/sse/acp"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
              Dashboard
            </.link>
            <.link navigate={~p"/sse/acp/npcs/new"} class="text-sm text-gray-400 hover:text-gray-200 transition-colors">
              New NPC
            </.link>
            <.link navigate={~p"/sse/acp/social"} class="text-sm text-amber-400 font-semibold border-b border-amber-400 pb-0.5">
              Social Log
            </.link>
          </div>
        </div>
        <button
          phx-click="trigger_tick"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-500/10 border border-amber-500/30 text-amber-400 text-xs font-semibold hover:bg-amber-500/20 transition-colors"
        >
          <.icon name="hero-arrow-path" class="size-3.5" /> Trigger Social Tick
        </button>
      </nav>

      <div class="flex-1 flex overflow-hidden">
        <%!-- Sidebar Scenes --%>
        <aside class="w-80 border-r border-gray-800 bg-gray-900/50 flex flex-col overflow-y-auto shrink-0">
          <div class="p-4 border-b border-gray-800 shrink-0">
            <h2 class="text-sm font-bold text-gray-400 uppercase tracking-wider">Autonomous Chats</h2>
            <p class="text-[10px] text-gray-600 mt-0.5">Background NPC-NPC interactions</p>
          </div>
          <div class="flex-1 divide-y divide-gray-800/40">
            <%= if @scenes == [] do %>
              <div class="p-6 text-center text-xs text-gray-600 italic">No autonomous scenes found yet. Trigger a tick to start.</div>
            <% else %>
              <%= for scene <- @scenes do %>
                <button
                  phx-click={JS.patch(~p"/sse/acp/social?id=#{scene.id}")}
                  class={["w-full p-4 text-left transition-colors hover:bg-gray-800/20 flex flex-col gap-1.5",
                    @selected_scene && @selected_scene.id == scene.id && "bg-gray-800/40 border-l-2 border-amber-400"
                  ]}
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-xs font-bold text-gray-200 truncate">{scene.title}</span>
                    <span class="text-[9px] text-gray-600 shrink-0">{format_time(scene.inserted_at)}</span>
                  </div>
                  <div class="text-[10px] text-gray-500 font-medium truncate">
                    Location: {scene.location || "Unknown"}
                  </div>
                </button>
              <% end %>
            <% end %>
          </div>
        </aside>

        <%!-- Content Area --%>
        <main class="flex-1 flex flex-col bg-gray-950 overflow-hidden">
          <%= if is_nil(@selected_scene) do %>
            <div class="flex-1 flex flex-col items-center justify-center text-center p-8">
              <.icon name="hero-chat-bubble-left-right" class="size-12 text-gray-800 mb-3" />
              <h3 class="text-sm font-bold text-gray-400 uppercase tracking-wide">No Active Scene</h3>
              <p class="text-xs text-gray-600 mt-1">Select an autonomous scene from the sidebar to inspect its timeline.</p>
            </div>
          <% else %>
            <%!-- Header --%>
            <header class="px-6 py-4 border-b border-gray-800 bg-gray-900/20 shrink-0">
              <div class="flex items-center justify-between">
                <div>
                  <h1 class="text-base font-bold text-gray-100">{@selected_scene.title}</h1>
                  <p class="text-[10px] text-gray-500 mt-0.5">Location: {@selected_scene.location} | Status: {@selected_scene.status}</p>
                </div>
                <div class="flex items-center gap-1.5">
                  <%= for part <- @selected_scene.participants do %>
                    <span class="text-[9px] px-2 py-0.5 rounded border bg-amber-500/10 text-amber-400 border-amber-500/20 font-semibold">
                      {part.character.name}
                    </span>
                  <% end %>
                </div>
              </div>
            </header>

            <%!-- Messages Stream --%>
            <div class="flex-1 overflow-y-auto px-6 py-6 space-y-4">
              <%= if @messages == [] do %>
                <div class="text-center text-xs text-gray-600 italic py-12">No messages recorded in this scene.</div>
              <% else %>
                <%= for msg <- @messages do %>
                  <%= if msg.message_type == "action" do %>
                    <div class="flex items-start gap-2 px-2 py-0.5 mx-auto max-w-[90%] w-full">
                      <div class="flex-1 text-center">
                        <p class="text-xs italic text-amber-400/80 leading-relaxed font-medium">
                          **{msg.content}**
                        </p>
                      </div>
                    </div>
                  <% else %>
                    <div class="flex gap-3 max-w-[85%] mr-auto">
                      <div class="shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30">
                        {String.first(character_name(@selected_scene.participants, msg.character_id))}
                      </div>
                      <div class="flex-1 min-w-0">
                        <div class="text-[10px] font-semibold text-amber-400/75 mb-0.5 ml-1">
                          {character_name(@selected_scene.participants, msg.character_id)}
                        </div>
                        <div class="px-4 py-2.5 rounded-2xl bg-gray-900 border border-gray-800 text-sm leading-relaxed text-gray-200 rounded-tl-md">
                          <p class="whitespace-pre-wrap break-words">{msg.content}</p>
                          <%= if msg.private_thought && msg.private_thought != "" do %>
                            <div class="mt-2 pt-1.5 border-t border-purple-500/20 text-[10px] text-purple-400 font-mono">
                              <span class="font-bold">🧠 Thought:</span> {msg.private_thought}
                            </div>
                          <% end %>
                        </div>
                        <div class="text-[9px] text-gray-600 mt-1 ml-1">
                          {format_time(msg.inserted_at)}
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </main>
      </div>
    </div>
    """
  end

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M")

  defp character_name(participants, character_id) do
    case Enum.find(participants, &(&1.character_id == character_id)) do
      nil -> "Unknown"
      part -> part.character.name
    end
  end
end
