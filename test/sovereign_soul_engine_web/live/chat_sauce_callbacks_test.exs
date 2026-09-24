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
end
