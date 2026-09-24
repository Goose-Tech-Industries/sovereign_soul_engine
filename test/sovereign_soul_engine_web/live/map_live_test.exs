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
end
