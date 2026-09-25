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

  test "character ACP updates drafts, toggles scenes, and safely ignores empty writes" do
    {:ok, character} =
      Characters.create_character(%{
        name: "Draft NPC",
        slug: "draft-npc-#{System.unique_integer([:positive])}",
        kind: "npc",
        status: "active"
      })

    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = AcpCharacterLive.mount(%{"id" => character.id}, %{}, socket)
    socket = %{
      socket
      | assigns:
          Map.merge(socket.assigns, %{
            emotional_draft: %{"anger" => 0, "stress" => 0},
            soul_draft: %{"speech_style" => "", "personality_traits" => %{}},
            expanded_scene_ids: MapSet.new()
          })
    }

    {:noreply, socket} =
      AcpCharacterLive.handle_event("update_emotional_draft", %{"anger" => "55", "stress" => "31"}, socket)

    assert socket.assigns.emotional_draft["anger"] == "55"
    assert socket.assigns.emotional_draft["stress"] == "31"

    {:noreply, socket} =
      AcpCharacterLive.handle_event("update_soul_draft", %{"speech_style" => "measured"}, socket)

    assert socket.assigns.soul_draft["speech_style"] == "measured"
    {:noreply, socket} = AcpCharacterLive.handle_event("toggle_soul_trait", %{"trait" => "brave"}, socket)
    assert socket.assigns.soul_draft["personality_traits"]["brave"] == true

    {:noreply, socket} = AcpCharacterLive.handle_event("add_goal", %{"goal" => "   "}, socket)
    {:noreply, socket} = AcpCharacterLive.handle_event("add_grief_arc", %{"subject" => "   "}, socket)
    {:noreply, socket} = AcpCharacterLive.handle_event("add_relationship", %{"target_id" => ""}, socket)
    assert socket.assigns.active_goals == []

    {:noreply, socket} =
      AcpCharacterLive.handle_event("toggle_scene_expand", %{"scene_id" => "scene-1"}, socket)

    assert MapSet.member?(socket.assigns.expanded_scene_ids, "scene-1")
  end
end
