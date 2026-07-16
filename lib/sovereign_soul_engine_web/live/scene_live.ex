defmodule SovereignSoulEngineWeb.SceneLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.SoulEvents
  alias SovereignSoulEngine.Souls.ConsequenceEngine

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scene = Scenes.get_scene!(id)
    participants = Scenes.list_participants(id)
    character_ids = Enum.map(participants, & &1.character_id)
    characters = Enum.map(character_ids, &Characters.get_character!(&1))
    messages = Scenes.list_messages(id)

    socket =
      socket
      |> assign(:page_title, "#{scene.title} — Scene")
      |> assign(:scene, scene)
      |> assign(:participants, participants)
      |> assign(:character_ids, character_ids)
      |> assign(:characters, characters)
      |> assign(:messages, messages)
      |> assign(:inspector_character_id, nil)
      |> assign(:inspector_data, nil)
      |> assign(:event_result, nil)
      |> assign(:message_form, to_form(%{"content" => ""}, as: :message))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "scene:#{id}")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "dashboard")
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scene = Scenes.get_scene!(id)
    messages = Scenes.list_messages(id)
    {:noreply, assign(socket, :scene, scene) |> assign(:messages, messages)}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    unless String.trim(content) == "" do
      scene = socket.assigns.scene

      character =
        Enum.find(socket.assigns.characters, &(&1.kind == "player")) ||
          List.first(socket.assigns.characters)

      if character do
        {:ok, msg} =
          Scenes.create_message(%{
            scene_id: scene.id,
            character_id: character.id,
            content: content,
            message_type: "dialogue"
          })

        correlation_id = Ecto.UUID.generate()

        # Broadcast the new message
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "scene:#{scene.id}",
          {:new_message, msg}
        )

        # Run consequence engine and response generation for all NPCs in the scene
        participant_npcs =
          socket.assigns.characters
          |> Enum.filter(&(&1.kind == "npc" and &1.status == "active"))

        participant_npcs
        |> Enum.with_index()
        |> Enum.each(fn {npc, index} ->
          delay_ms = index * 4000

          ConsequenceEngine.resolve(%{
            character_id: character.id,
            source_character_id: character.id,
            target_character_id: npc.id,
            scene_id: scene.id,
            event_type: :speak,
            event_intensity: 30,
            message_content: content,
            correlation_id: correlation_id
          })

          # Broadcast character updates
          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            "character:#{npc.id}",
            {:emotion_updated, %{}}
          )

          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            "dashboard",
            {:ledger_updated, %{}}
          )

          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            "scene:#{scene.id}",
            {:state_updated, %{character_id: npc.id}}
          )

          # Trigger NPC response generation (synchronously in test to bypass Ecto sandbox issues)
          if Mix.env() == :test do
            generate_npc_response(npc, character, scene, content)
          else
            Task.start(fn ->
              :timer.sleep(delay_ms)
              generate_npc_response(npc, character, scene, content)
            end)
          end
        end)
      end
    end

    messages = Scenes.list_messages(socket.assigns.scene.id)

    {:noreply,
     assign(socket, :messages, messages)
     |> assign(:message_form, to_form(%{"content" => ""}, as: :message))}
  end

  @impl true
  def handle_event(
        "inject_event",
        %{"event_type" => event_type, "intensity" => intensity_str},
        socket
      ) do
    scene = socket.assigns.scene
    intensity = String.to_integer(intensity_str)

    player =
      Enum.find(socket.assigns.characters, &(&1.kind == "player")) ||
        List.first(socket.assigns.characters)

    npc =
      Enum.find(socket.assigns.characters, &(&1.kind == "npc")) ||
        List.last(socket.assigns.characters)

    socket =
      if player && npc do
        correlation_id = Ecto.UUID.generate()

        event_type_atom = String.to_atom(event_type)

        # Create the soul event
        {:ok, _event} =
          SoulEvents.create_event(%{
            scene_id: scene.id,
            source_character_id: player.id,
            target_character_id: npc.id,
            event_type: event_type,
            intensity: intensity,
            occurred_at: DateTime.utc_now(),
            correlation_id: correlation_id
          })

        result =
          ConsequenceEngine.resolve(%{
            character_id: player.id,
            source_character_id: player.id,
            target_character_id: npc.id,
            scene_id: scene.id,
            event_type: event_type_atom,
            event_intensity: intensity,
            message_content: "[#{event_type} event — intensity #{intensity}]",
            correlation_id: correlation_id
          })

        # Broadcast updates
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "scene:#{scene.id}",
          {:event_injected,
           %{event_type: event_type, intensity: intensity, source: player.id, target: npc.id}}
        )

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "character:#{npc.id}",
          {:emotion_updated, %{}}
        )

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "character:#{npc.id}",
          {:relationship_updated, %{}}
        )

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "dashboard",
          {:ledger_updated, %{}}
        )

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "ledger",
          {:ledger_updated, %{}}
        )

        case result do
          {:ok, _} ->
            assign(socket, :event_result, %{status: :ok, type: event_type, intensity: intensity})

          {:error, _op, _val, _} ->
            assign(socket, :event_result, %{
              status: :error,
              type: event_type,
              intensity: intensity
            })
        end
      else
        assign(socket, :event_result, %{status: :error, reason: "Need both player and NPC"})
      end

    messages = Scenes.list_messages(scene.id)
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_event("inspect_character", %{"character_id" => id}, socket) do
    char = Characters.get_character!(id)
    emotional = Souls.get_emotional_state_by_character(id)
    relationships = Relationships.list_relationships_for_source(id)
    memories = Memories.list_memories_for_character(id) |> Enum.take(10)

    inspector_data = %{
      character: char,
      emotional_state: emotional,
      relationships: relationships,
      memories: memories
    }

    {:noreply,
     assign(socket, :inspector_character_id, id) |> assign(:inspector_data, inspector_data)}
  end

  @impl true
  def handle_info({:new_message, _msg}, socket) do
    messages = Scenes.list_messages(socket.assigns.scene.id)
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:event_injected, _data}, socket) do
    messages = Scenes.list_messages(socket.assigns.scene.id)
    socket = assign(socket, :messages, messages)

    # Refresh inspector data if viewing
    socket =
      if socket.assigns.inspector_character_id do
        handle_event(
          "inspect_character",
          %{"character_id" => socket.assigns.inspector_character_id},
          socket
        )
        |> elem(1)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:state_updated, %{character_id: id}}, socket) do
    socket =
      if socket.assigns.inspector_character_id == id do
        handle_event("inspect_character", %{"character_id" => id}, socket) |> elem(1)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp character_name(characters, id) do
    char = Enum.find(characters, &(&1.id == id))
    if char, do: char.name, else: "(unknown)"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-4">
        <%!-- Top nav --%>
        <div class="flex items-center justify-between">
          <.link
            navigate={~p"/sse"}
            class="text-sm text-base-content/60 hover:text-base-content transition-colors"
          >
            <.icon name="hero-arrow-left" class="size-4 inline" /> Dashboard
          </.link>
          <div class="flex items-center gap-2">
            <span class={[
              "inline-block w-2 h-2 rounded-full",
              @scene.status == "active" && "bg-emerald-500",
              @scene.status == "pending" && "bg-amber-400"
            ]}>
            </span>
            <h1 class="text-lg font-semibold text-base-content">{@scene.title}</h1>
          </div>
          <div class="w-24"></div>
        </div>

        <div class="flex gap-4 h-[calc(100vh-180px)] min-h-[500px]">
          <%!-- Left: Participants + Chat --%>
          <div class="flex-1 flex flex-col min-w-0">
            <%!-- Participants bar --%>
            <div class="flex items-center gap-2 mb-3 p-2 rounded-lg border border-base-300 bg-base-200/30">
              <span class="text-xs text-base-content/50 mr-1">In scene:</span>
              <%= for char <- @characters do %>
                <button
                  phx-click="inspect_character"
                  phx-value-character_id={char.id}
                  class={[
                    "text-xs px-2 py-1 rounded-full transition-colors",
                    char.id == @inspector_character_id && "bg-primary/20 text-primary font-medium",
                    char.id != @inspector_character_id &&
                      "bg-base-300 text-base-content/70 hover:bg-base-300/80"
                  ]}
                >
                  {char.name}
                </button>
              <% end %>
            </div>

            <%!-- Chat messages area --%>
            <div id="scene-messages" class="flex-1 overflow-y-auto space-y-3 pr-2">
              <div
                :for={msg <- @messages}
                id={"msg-#{msg.id}"}
                class="p-3 rounded-lg border border-base-300 bg-base-200/30"
              >
                <div class="flex items-center gap-2 mb-1">
                  <span class="text-xs font-semibold text-primary/80">
                    {character_name(@characters, msg.character_id)}
                  </span>
                  <span class="text-xs text-base-content/30">{format_time(msg.inserted_at)}</span>
                </div>
                <p class="text-sm text-base-content whitespace-pre-wrap">{msg.content}</p>
                <%= if Map.get(msg, :private_thought) && Map.get(msg, :private_thought) != "" do %>
                  <div class="mt-2 p-2 rounded bg-purple-500/10 border border-purple-500/20 text-xs text-purple-400 font-mono">
                    <span class="font-semibold">🧠 Private Thought:</span> {msg.private_thought}
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Message input --%>
            <div class="mt-3">
              <.form
                for={@message_form}
                id="message-form"
                phx-submit="send_message"
                class="flex gap-2"
              >
                <.input
                  field={@message_form[:content]}
                  type="text"
                  placeholder="Type a message..."
                  class="flex-1"
                  autocomplete="off"
                />
                <.button type="submit" id="send-message-btn" phx-disable-with="Sending...">
                  Send
                </.button>
              </.form>
            </div>

            <%!-- Event Injector --%>
            <details class="mt-3">
              <summary class="cursor-pointer text-xs font-medium text-base-content/50 uppercase tracking-wider hover:text-base-content/70 transition-colors select-none">
                Event Injector
              </summary>
              <div class="mt-2 p-3 rounded-lg border border-amber-500/30 bg-amber-500/5">
                <p class="text-xs text-base-content/50 mb-2">
                  Inject a canonical soul event into this scene.
                </p>
                <div class="grid grid-cols-3 sm:grid-cols-4 gap-1.5">
                  <%= for {event_type, label} <- event_labels() do %>
                    <div>
                      <div class="text-xs text-base-content/40 mb-0.5">{label}</div>
                      <button
                        id={"inject-#{event_type}"}
                        phx-click="inject_event"
                        phx-value-event_type={event_type}
                        phx-value-intensity="75"
                        class="w-full text-xs px-2 py-1.5 rounded bg-base-300 hover:bg-base-300/70 text-base-content/80 transition-colors"
                      >
                        Inject
                      </button>
                    </div>
                  <% end %>
                </div>
                <%= if @event_result do %>
                  <div class={[
                    "mt-3 p-2 rounded text-xs",
                    @event_result.status == :ok && "bg-emerald-500/10 text-emerald-400",
                    @event_result.status == :error && "bg-red-500/10 text-red-400"
                  ]}>
                    {@event_result.status == :ok &&
                      "Injected #{@event_result.type} (intensity #{@event_result.intensity}) — consequence resolved."}
                    {@event_result.status == :error && "Failed to inject #{@event_result.type}"}
                  </div>
                <% end %>
              </div>
            </details>
          </div>

          <%!-- Right: Soul Inspector --%>
          <div class="w-80 shrink-0 space-y-4 overflow-y-auto pr-2">
            <%= if @inspector_data do %>
              <% data = @inspector_data %>
              <div class="p-4 rounded-xl border border-emerald-500/30 bg-emerald-500/5">
                <h2 class="text-sm font-semibold text-emerald-400 flex items-center gap-1.5 mb-3">
                  <.icon name="hero-eye" class="size-4" /> Soul Inspector: {data.character.name}
                </h2>

                <%!-- Emotions --%>
                <div class="mb-4">
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
                    Emotions
                  </h3>
                  <div class="space-y-1.5">
                    <%= for {label, key, color} <- emotion_fields() do %>
                      <div>
                        <div class="flex justify-between text-xs">
                          <span class="text-base-content/60">{label}</span>
                          <span class="text-base-content/80">
                            {Map.get(data.emotional_state || %{}, key) || 0}
                          </span>
                        </div>
                        <div class="h-1.5 w-full rounded-full bg-base-300 overflow-hidden mt-0.5">
                          <div
                            class="h-full rounded-full transition-all duration-500"
                            style={"width: #{Map.get(data.emotional_state || %{}, key) || 0}%; background-color: #{color}"}
                          >
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>

                <%!-- Relationships --%>
                <div class="mb-4">
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
                    Relationships
                  </h3>
                  <div
                    :if={(data.relationships || []) == []}
                    class="text-xs text-base-content/40 italic"
                  >
                    No relationships
                  </div>
                  <%= for rel <- data.relationships || [] do %>
                    <div class="mb-2 p-2 rounded bg-base-200/50 border border-base-300">
                      <div class="flex justify-between items-center mb-1">
                        <span class="text-xs text-base-content/60">Toward</span>
                        <span class="text-xs text-base-content">
                          {character_name(@characters, rel.target_character_id)}
                        </span>
                      </div>
                      <div class="grid grid-cols-5 gap-1">
                        <%= for {label, key} <- rel_dimensions() do %>
                          <div class="text-center">
                            <div class="text-[10px] text-base-content/40">{label}</div>
                            <div class={[
                              "text-xs font-medium",
                              rel_val_class(
                                data.relationships
                                |> List.first()
                                |> then(&(Map.get(&1 || %{}, key) || 0))
                              )
                            ]}>
                              {Map.get(rel, key) || 0}
                            </div>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>

                <%!-- Recent Memories --%>
                <div>
                  <h3 class="text-xs font-medium text-base-content/50 uppercase tracking-wider mb-2">
                    Recent Memories
                  </h3>
                  <div :if={(data.memories || []) == []} class="text-xs text-base-content/40 italic">
                    No memories
                  </div>
                  <div class="space-y-1">
                    <%= for mem <- data.memories || [] do %>
                      <div class="p-2 rounded bg-base-200/50 border border-base-300">
                        <p class="text-xs text-base-content truncate">{mem.summary}</p>
                        <div class="flex gap-2 mt-1 text-[10px] text-base-content/40">
                          <span>{mem.category}</span>
                          <span>Imp: {mem.importance || 0}</span>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="p-4 rounded-xl border border-base-300 bg-base-200/20">
                <p class="text-sm text-base-content/50 text-center">
                  Click a character name above to open the Soul Inspector.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp emotion_fields do
    [
      {"Anger", :anger, "#ef4444"},
      {"Fear", :fear, "#a855f7"},
      {"Stress", :stress, "#f59e0b"},
      {"Gratitude", :gratitude, "#10b981"},
      {"Confidence", :confidence, "#3b82f6"},
      {"Sadness", :sadness, "#6b7280"},
      {"Curiosity", :curiosity, "#06b6d4"},
      {"Attachment", :attachment, "#ec4899"}
    ]
  end

  defp rel_dimensions do
    [
      {"Affin", :affinity},
      {"Trust", :trust},
      {"Resp", :respect},
      {"Fear", :fear},
      {"Anger", :anger},
      {"Grat", :gratitude},
      {"Debt", :debt},
      {"Soft", :softening},
      {"Hard", :hardening},
      {"Wound", :wound}
    ]
  end

  defp event_labels do
    [
      {"betrayed_me", "Betrayed"},
      {"ally_saved_me", "Ally Saved"},
      {"insulted_me", "Insulted"},
      {"praised_me", "Praised"},
      {"protected_me", "Protected"},
      {"abandoned_me", "Abandoned"},
      {"attacked_me", "Attacked"},
      {"healed_me", "Healed"},
      {"apologized_to_me", "Apologized"},
      {"threatened_me", "Threatened"},
      {"shared_secret", "Shared Secret"},
      {"lied_to_me", "Lied To"},
      {"gave_item", "Gave Item"},
      {"trained_me", "Trained"}
    ]
  end

  defp generate_npc_response(npc, player, scene, _user_message) do
    SovereignSoulEngine.Souls.Generator.generate(npc.id, scene.id, player.id)
  end

  defp rel_val_class(val) when val > 0, do: "text-emerald-400"
  defp rel_val_class(val) when val < 0, do: "text-red-400"
  defp rel_val_class(_), do: "text-base-content/60"

  defp format_time(nil), do: "--"
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")
end
