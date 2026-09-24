defmodule SovereignSoulEngineWeb.AcpCharacterCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngineWeb.AcpCharacterLive

  test "character ACP handles theory-of-mind drafts and safe empty saves" do
    {:ok, character} =
      Characters.create_character(%{
        name: "Callback NPC",
        slug: "callback-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    assert {:ok, socket} = AcpCharacterLive.mount(%{"id" => character.id}, %{}, socket)

    {:noreply, socket} =
      AcpCharacterLive.handle_event(
        "update_tom_draft",
        %{"known_fact" => "Values honesty", "certainty" => "88", "is_assumption" => "false"},
        socket
      )

    assert socket.assigns.tom_draft_fact == "Values honesty"
    assert socket.assigns.tom_draft_certainty == 88
    assert socket.assigns.tom_draft_assumption == false

    {:noreply, socket} = AcpCharacterLive.handle_event("save_tom_entry", %{}, socket)
    assert socket.assigns.tom_save_result == :error

    {:noreply, socket} =
      AcpCharacterLive.handle_event("search_memories", %{"query" => "honesty"}, socket)

    assert socket.assigns.memories == []
    {:noreply, socket} = AcpCharacterLive.handle_info(:unexpected, socket)
    assert socket.assigns.id == character.id
  end
end
