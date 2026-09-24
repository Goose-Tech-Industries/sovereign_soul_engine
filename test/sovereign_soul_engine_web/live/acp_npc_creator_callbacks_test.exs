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
end
