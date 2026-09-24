defmodule SovereignSoulEngineWeb.ChatSauceCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.ChatSauceLive

  test "Chat Sauce tab and wizard callbacks update real socket state" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket, _opts} = ChatSauceLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      ChatSauceLive.handle_event("switch_sauce_tab", %{"tab" => "social"}, socket)

    assert socket.assigns.sauce_tab == "social"

    {:noreply, socket} =
      ChatSauceLive.handle_event("switch_sauce_tab", %{"tab" => "characters"}, socket)

    assert socket.assigns.sauce_tab == "characters"

    {:noreply, socket} =
      ChatSauceLive.handle_event("w_update_identity", %{"name" => "Night Raven"}, socket)

    assert socket.assigns.w_name == "Night Raven"
    assert socket.assigns.w_slug == "night-raven"

    {:noreply, socket} =
      ChatSauceLive.handle_event("w_auto_slug", %{"name" => "Iron Crow"}, socket)

    assert socket.assigns.w_slug == "iron-crow"

    {:noreply, socket} =
      ChatSauceLive.handle_event("w_update_core_value_input", %{"value" => "Honor"}, socket)

    {:noreply, socket} = ChatSauceLive.handle_event("w_add_core_value", %{}, socket)
    assert socket.assigns.w_core_values == ["Honor"]

    {:noreply, socket} =
      ChatSauceLive.handle_event("w_toggle_trait", %{"trait" => "bipolar"}, socket)

    assert socket.assigns.w_personality_traits["bipolar"]
    {:noreply, socket} = ChatSauceLive.handle_event("w_next_step", %{}, socket)
    assert socket.assigns.w_step == 2
    {:noreply, socket} = ChatSauceLive.handle_info(:tick, socket)
    assert socket.assigns.w_step == 2
  end

  test "Chat Sauce wizard covers the remaining draft collections" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket, _} = ChatSauceLive.mount(%{}, %{}, socket)

    events = [
      {"w_update_baseline_emotion", %{"emotion" => "anger", "value" => "35"}},
      {"w_update_physical_tell", %{"emotion" => "anger", "value" => "tight jaw"}},
      {"w_update_transference",
       %{"index" => "0", "field" => "trigger_pattern", "value" => "storms"}},
      {"w_update_belief_draft",
       %{"belief" => "Trust is earned", "domain" => "social", "conviction" => "75"}},
      {"w_add_belief", %{}},
      {"w_update_trigger_draft",
       %{"topic" => "betrayal", "reaction_type" => "anger_spike", "intensity_modifier" => "60"}},
      {"w_add_trigger", %{}},
      {"w_update_moral_line_draft", %{"principle" => "Protect innocents"}},
      {"w_add_moral_line", %{}},
      {"w_update_secret_draft", %{"secret_text" => "Lost a brother", "domain" => "family"}},
      {"w_add_secret", %{}},
      {"w_update_desire_draft",
       %{"desire" => "Belonging", "domain" => "connection", "urgency" => "80"}},
      {"w_add_desire", %{}},
      {"w_update_goal_draft",
       %{"goal" => "Find the truth", "current_step" => "Investigate", "priority" => "90"}},
      {"w_add_goal", %{}},
      {"w_update_grief_draft",
       %{"subject" => "Brother", "loss_type" => "person", "intensity" => "70"}},
      {"w_add_grief_arc", %{}},
      {"w_update_forgiveness_draft",
       %{"wound_description" => "Betrayal", "direction" => "healing", "intensity" => "60"}},
      {"w_add_forgiveness_arc", %{}},
      {"w_update_tom_draft", %{"known_fact" => "The gate is closed", "certainty" => "80"}},
      {"w_add_tom_entry", %{}},
      {"w_update_stamina",
       %{
         "social_stamina" => "70",
         "stamina_regen_rate" => "12",
         "stamina_max" => "100",
         "hunger" => "10",
         "pain" => "0",
         "fatigue" => "25",
         "illness_severity" => "0"
       }}
    ]

    socket =
      Enum.reduce(events, socket, fn {event, params}, socket ->
        {:noreply, socket} = ChatSauceLive.handle_event(event, params, socket)
        socket
      end)

    assert socket.assigns.w_baseline_emotions["anger"] == 35
    assert socket.assigns.w_physical_tells["anger"] == "tight jaw"
    assert socket.assigns.w_beliefs != []
    assert socket.assigns.w_triggers != []
    assert socket.assigns.w_moral_lines != []
    assert socket.assigns.w_secrets != []
    assert socket.assigns.w_desires != []
    assert socket.assigns.w_goals != []
    assert socket.assigns.w_grief_arcs != []
    assert socket.assigns.w_forgiveness_arcs != []
    assert socket.assigns.w_tom_entries != []
    assert socket.assigns.w_social_stamina == 70
  end
end
