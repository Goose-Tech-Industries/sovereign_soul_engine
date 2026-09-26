defmodule SovereignSoulEngineWeb.AcpNpcCreatorCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.AcpNpcCreatorLive

  test "creator callback state machine handles identity, personality, soul, and navigation" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = AcpNpcCreatorLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event("update_identity", %{"name" => "Raven Guard"}, socket)

    assert socket.assigns.slug == "raven-guard"

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event("auto_slug", %{"name" => "Night Fox"}, socket)

    assert socket.assigns.slug == "night-fox"

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event(
        "update_personality",
        %{
          "attachment_style" => "secure",
          "humor_style" => "dry",
          "emotional_susceptibility" => "80"
        },
        socket
      )

    assert socket.assigns.emotional_susceptibility == 80

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event("toggle_trait", %{"trait" => "brave"}, socket)

    assert socket.assigns.personality_traits["brave"] == true

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event("update_core_value_input", %{"value" => "Honor"}, socket)

    {:noreply, socket} = AcpNpcCreatorLive.handle_event("add_core_value", %{}, socket)
    assert socket.assigns.core_values == ["Honor"]

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event("remove_core_value", %{"value" => "Honor"}, socket)

    assert socket.assigns.core_values == []

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event(
        "update_baseline_emotion",
        %{"emotion" => "anger", "value" => "42"},
        socket
      )

    assert socket.assigns.baseline_emotions["anger"] == 42

    {:noreply, socket} =
      AcpNpcCreatorLive.handle_event(
        "update_physical_tell",
        %{"emotion" => "anger", "value" => " clenched jaw "},
        socket
      )

    assert socket.assigns.physical_tells["anger"] == " clenched jaw "

    {:noreply, socket} = AcpNpcCreatorLive.handle_event("goto_step", %{"step" => "7"}, socket)
    assert socket.assigns.step == 7
    {:noreply, socket} = AcpNpcCreatorLive.handle_event("prev_step", %{}, socket)
    assert socket.assigns.step == 6
  end

  test "creator drafts cover beliefs, triggers, boundaries, motivations, and arcs" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = AcpNpcCreatorLive.mount(%{}, %{}, socket)

    callbacks = [
      {"update_transference", %{"index" => "0", "field" => "pattern", "value" => "trust"}},
      {"update_belief_draft",
       %{"belief" => "Truth matters", "domain" => "social", "conviction" => "91"}},
      {"add_belief", %{}},
      {"remove_belief", %{"index" => "0"}},
      {"update_trigger_draft",
       %{
         "topic" => "betrayal",
         "reaction_type" => "anger_spike",
         "intensity_modifier" => "77",
         "flavor_text" => "goes quiet"
       }},
      {"add_trigger", %{}},
      {"remove_trigger", %{"index" => "0"}},
      {"update_moral_line_draft", %{"principle" => "Protect the innocent"}},
      {"add_moral_line", %{}},
      {"remove_moral_line", %{"index" => "0"}},
      {"update_secret_draft",
       %{"secret_text" => "Hidden oath", "risk_level" => "high", "domain" => "past"}},
      {"add_secret", %{}},
      {"remove_secret", %{"index" => "0"}},
      {"update_desire_draft",
       %{"desire" => "Belonging", "domain" => "connection", "urgency" => "82"}},
      {"add_desire", %{}},
      {"remove_desire", %{"index" => "0"}},
      {"update_goal_draft",
       %{"goal" => "Find allies", "current_step" => "Listen", "priority" => "66"}},
      {"add_goal", %{}},
      {"remove_goal", %{"index" => "0"}},
      {"update_grief_draft",
       %{"subject" => "Old home", "loss_type" => "home", "stage" => "denial", "intensity" => "61"}},
      {"add_grief_arc", %{}},
      {"remove_grief_arc", %{"index" => "0"}},
      {"update_forgiveness_draft",
       %{
         "wound_description" => "Broken promise",
         "stage" => "fresh",
         "direction" => "healing",
         "intensity" => "55"
       }},
      {"add_forgiveness_arc", %{}},
      {"remove_forgiveness_arc", %{"index" => "0"}}
    ]

    socket =
      Enum.reduce(callbacks, socket, fn {event, params}, socket ->
        {:noreply, socket} = AcpNpcCreatorLive.handle_event(event, params, socket)
        socket
      end)

    assert socket.assigns.beliefs == []
    assert socket.assigns.triggers == []
    assert socket.assigns.moral_lines == []
    assert socket.assigns.secrets == []
    assert socket.assigns.desires == []
    assert socket.assigns.goals == []
    assert socket.assigns.grief_arcs == []
    assert socket.assigns.forgiveness_arcs == []
  end
end
