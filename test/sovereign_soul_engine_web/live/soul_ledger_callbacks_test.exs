defmodule SovereignSoulEngineWeb.SoulLedgerCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngineWeb.SoulLedgerLive

  test "ledger filter and refresh callbacks handle all filter states" do
    {:ok, character} =
      Characters.create_character(%{
        name: "Ledger NPC",
        slug: "ledger-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = SoulLedgerLive.mount(%{}, %{}, socket)

    {:noreply, socket} =
      SoulLedgerLive.handle_event("filter_character", %{"character_id" => character.id}, socket)

    assert socket.assigns.filter_character_id == character.id

    {:noreply, socket} =
      SoulLedgerLive.handle_event("filter_character", %{"character_id" => ""}, socket)

    assert socket.assigns.filter_character_id == nil
    {:noreply, socket} = SoulLedgerLive.handle_info({:ledger_updated, %{}}, socket)
    assert is_list(socket.assigns.ledger_entries)
    {:noreply, socket} = SoulLedgerLive.handle_info(:unknown, socket)
    assert is_list(socket.assigns.ledger_entries)
  end
end
