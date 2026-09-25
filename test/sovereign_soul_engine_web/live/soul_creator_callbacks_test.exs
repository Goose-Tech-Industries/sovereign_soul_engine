defmodule SovereignSoulEngineWeb.SoulCreatorCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.SoulCreatorLive

  test "creator selection and validation callbacks update the companion draft" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}
    {:ok, socket} = SoulCreatorLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      SoulCreatorLive.handle_event(
        "validate",
        %{"soul" => %{"name" => "Jarvis", "description" => "Guide", "greeting" => "Hello"}},
        socket
      )

    assert socket.assigns.name == "Jarvis"

    {:noreply, socket} =
      SoulCreatorLive.handle_event("select_archetype", %{"key" => "Wise Mentor"}, socket)

    assert socket.assigns.archetype == "Wise Mentor"

    {:noreply, socket} =
      SoulCreatorLive.handle_event("select_avatar", %{"url" => "custom"}, socket)

    assert socket.assigns.avatar_url == "custom"

    {:noreply, socket} =
      SoulCreatorLive.handle_event("toggle_sanctuary", %{"world" => "true"}, socket)

    assert socket.assigns.in_living_world

    {:noreply, socket} =
      SoulCreatorLive.handle_event("save_soul", %{"soul" => %{"name" => "Jarvis"}}, socket)

    assert socket.assigns.user == nil
  end
end
