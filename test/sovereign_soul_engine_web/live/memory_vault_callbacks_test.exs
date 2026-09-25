defmodule SovereignSoulEngineWeb.MemoryVaultCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngineWeb.MemoryVaultLive

  test "memory vault filters and refreshes on memory events" do
    {:ok, character} =
      Characters.create_character(%{
        name: "Memory NPC",
        slug: "memory-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = MemoryVaultLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      MemoryVaultLive.handle_event(
        "filter",
        %{"category" => "all", "character_id" => character.id},
        socket
      )

    assert socket.assigns.filter_character_id == character.id

    {:noreply, socket} =
      MemoryVaultLive.handle_event(
        "filter",
        %{"category" => "episodic", "character_id" => ""},
        socket
      )

    assert socket.assigns.filter_category == "episodic"
    {:noreply, socket} = MemoryVaultLive.handle_info({:memory_created, %{}}, socket)
    assert is_list(socket.assigns.memories)
    {:noreply, socket} = MemoryVaultLive.handle_info({:ledger_updated, %{}}, socket)
    assert is_list(socket.assigns.memories)
    {:noreply, socket} = MemoryVaultLive.handle_info(:unknown, socket)
    assert is_list(socket.assigns.memories)
  end
end
