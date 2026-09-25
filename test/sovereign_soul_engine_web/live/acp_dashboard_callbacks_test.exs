defmodule SovereignSoulEngineWeb.AcpDashboardCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngineWeb.AcpDashboardLive

  test "dashboard confirmation and cancellation callbacks update state" do
    {:ok, character} =
      Characters.create_character(%{
        name: "Dashboard NPC",
        slug: "dashboard-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = AcpDashboardLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      AcpDashboardLive.handle_event("confirm_kill", %{"id" => character.id}, socket)

    assert socket.assigns.confirm_kill_id == character.id
    {:noreply, socket} = AcpDashboardLive.handle_event("cancel_kill", %{}, socket)
    assert socket.assigns.confirm_kill_id == nil
    {:noreply, socket} = AcpDashboardLive.handle_info(:unknown, socket)
    assert is_list(socket.assigns.rows)
  end
end
