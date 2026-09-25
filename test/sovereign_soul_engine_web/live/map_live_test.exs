defmodule SovereignSoulEngineWeb.MapLiveTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.MapLive

  test "mounts the living map and handles movement controls" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    assert {:ok, mounted} = MapLive.mount(%{}, %{}, socket)
    assert mounted.assigns.player_district == "high_palace"
    assert mounted.assigns.view_mode == "rpg"

    assert {:noreply, moved} = MapLive.handle_event("set_view_mode", %{"mode" => "map"}, mounted)
    assert moved.assigns.view_mode == "map"

    assert {:noreply, sized} = MapLive.handle_event("set_tile_size", %{"size" => "42"}, moved)
    assert sized.assigns.tile_size == 42

    assert {:noreply, walked} =
             MapLive.handle_event("step_direction", %{"direction" => "north"}, sized)

    assert walked.assigns.travel_step_count == 1
    assert {:noreply, dismissed} = MapLive.handle_event("dismiss_arrival_banner", %{}, walked)
    assert dismissed.assigns.show_arrival_banner == false
  end

  test "handles invalid movement input without crashing" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, mounted} = MapLive.mount(%{}, %{}, socket)

    assert {:noreply, unchanged} =
             MapLive.handle_event("set_tile_size", %{"size" => "not-a-number"}, mounted)

    assert unchanged.assigns.tile_size == mounted.assigns.tile_size
  end

  test "covers map controls, keyboard routing, and ambient state" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = MapLive.mount(%{}, %{}, socket)

    {:noreply, socket} = MapLive.handle_event("toggle_view_mode", %{}, socket)
    assert socket.assigns.view_mode == "radar"
    {:noreply, socket} = MapLive.handle_event("walk_direction", %{"direction" => "east"}, socket)
    assert socket.assigns.last_direction == :east
    {:noreply, socket} = MapLive.handle_event("handle_keydown", %{"key" => "m"}, socket)
    assert socket.assigns.view_mode == "rpg"
    {:noreply, socket} = MapLive.handle_event("focus_ai_input", %{}, socket)
    {:noreply, socket} = MapLive.handle_event("handle_keydown", %{"key" => "w"}, socket)
    assert socket.assigns.ai_input_focused?
    {:noreply, socket} = MapLive.handle_event("blur_ai_input", %{}, socket)

    {:noreply, socket} =
      MapLive.handle_event("update_ai_prompt", %{"prompt" => "Describe this place"}, socket)

    assert socket.assigns.ai_prompt == "Describe this place"

    {:noreply, socket} =
      MapLive.handle_event("hail_soul", %{"name" => "Fia", "slug" => "fia"}, socket)

    assert socket.assigns.ambient_dialogue.name == "Fia"
    {:noreply, socket} = MapLive.handle_event("dismiss_ambient_dialogue", %{}, socket)
    assert socket.assigns.ambient_dialogue == nil
    {:noreply, socket} = MapLive.handle_event("interact_nearby", %{}, socket)
    assert is_map(socket.assigns)
  end
end
