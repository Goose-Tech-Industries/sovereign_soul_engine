defmodule SovereignSoulEngineWeb.Api.MemoryPurgeControllerTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.{Characters, Memories, TheoryOfMind}

  setup %{conn: conn} do
    {:ok, char} =
      Characters.create_character(%{
        name: "Amnesia Test Subject",
        slug: "amnesia-subject-#{Ecto.UUID.generate()}",
        kind: "npc",
        status: "active"
      })

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Seed memories
    {:ok, _m1} =
      Memories.create_memory(%{
        owner_character_id: char.id,
        summary: "Remembering the painful breakup at the coffee shop",
        category: "episodic",
        importance: 80,
        emotional_intensity: 75,
        occurred_at: now,
        status: "active",
        tags: ["breakup", "coffee"]
      })

    {:ok, _m2} =
      Memories.create_memory(%{
        owner_character_id: char.id,
        summary: "Studying cybernetics and robotics architecture",
        category: "core",
        importance: 60,
        emotional_intensity: 30,
        occurred_at: now,
        status: "active",
        tags: ["robotics", "study"]
      })

    # Seed Theory of Mind fact
    {:ok, _k} =
      TheoryOfMind.create_knowledge(%{
        knower_character_id: char.id,
        subject_character_id: char.id,
        known_fact: "Experienced a devastating breakup last year",
        certainty: 95
      })

    conn = authenticate_api(conn)
    %{conn: conn, character: char}
  end

  describe "POST /sse/api/memories/purge" do
    test "rejects missing, blank, and malformed filters without deleting", %{
      conn: conn,
      character: char
    } do
      for filters <- [
            %{},
            %{"topic" => " "},
            %{"category" => ""},
            %{"topic" => 12},
            %{"all" => "yes"}
          ] do
        response =
          post(conn, "/sse/api/memories/purge", Map.put(filters, "character_slug", char.slug))

        assert json_response(response, 400)["error"]
        assert length(Memories.list_memories_for_character(char.id)) == 2
        assert length(TheoryOfMind.list_knowledge_about(char.id, char.id)) == 1
      end
    end

    test "requires an explicit character even for all", %{conn: conn, character: char} do
      assert conn |> post("/api/memories/purge", %{all: true}) |> json_response(400)
      assert length(Memories.list_memories_for_character(char.id)) == 2
    end

    test "category purge preserves knowledge", %{conn: conn, character: char} do
      response = post(conn, "/api/memories/purge", %{character_slug: char.slug, category: "core"})
      assert json_response(response, 200)["memories_deleted"] == 1
      assert json_response(response, 200)["knowledge_facts_deleted"] == 0
      assert length(TheoryOfMind.list_knowledge_about(char.id, char.id)) == 1
    end

    test "domain functions reject unfiltered purges", %{character: char} do
      for opts <- [[], [topic: " "], [category: ""], [topic: 42], [all: "true"]] do
        assert {:error, :invalid_purge_filters} =
                 Memories.purge_memories_for_character(char.id, opts)

        assert {:error, :invalid_purge_filters} =
                 TheoryOfMind.purge_knowledge_about(char.id, char.id, opts)
      end

      assert length(Memories.list_memories_for_character(char.id)) == 2
      assert length(TheoryOfMind.list_knowledge_about(char.id, char.id)) == 1
    end

    test "SQL wildcard topics are literal", %{character: char} do
      for topic <- ["%", "_"] do
        assert {:ok, 0} = Memories.purge_memories_for_character(char.id, topic: topic)
        assert {:ok, 0} = TheoryOfMind.purge_knowledge_about(char.id, char.id, topic: topic)
      end
    end

    test "selectively purges memories by topic", %{conn: conn, character: char} do
      payload = %{
        "character_slug" => char.slug,
        "topic" => "breakup"
      }

      conn = post(conn, ~p"/sse/api/memories/purge", payload)
      assert json_response(conn, 200)["status"] == "ok"
      body = json_response(conn, 200)

      assert body["memories_deleted"] == 1
      assert body["knowledge_facts_deleted"] == 1

      # Inspect verifies only 1 memory remains (the robotics memory)
      remaining = Memories.list_memories_for_character(char.id)
      assert length(remaining) == 1
      assert hd(remaining).summary =~ "robotics"
    end

    test "purges all memories when all=true", %{conn: conn, character: char} do
      payload = %{
        "character_slug" => char.slug,
        "all" => true
      }

      conn = post(conn, ~p"/sse/api/memories/purge", payload)
      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["memories_deleted"] == 2

      assert Memories.list_memories_for_character(char.id) == []
    end
  end

  describe "GET /sse/api/memories/inspect" do
    test "returns list of active memories", %{conn: conn, character: char} do
      conn = get(conn, ~p"/sse/api/memories/inspect?character_slug=#{char.slug}")
      assert json_response(conn, 200)["status"] == "ok"
      assert json_response(conn, 200)["count"] == 2
    end
  end
end
