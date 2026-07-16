defmodule SovereignSoulEngine.LLM.ProviderCascadeTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.LLM.ProviderCascade
  alias SovereignSoulEngine.LLM.FakeProvider

  setup do
    pid = start_supervised!({FakeProvider, name: FakeProvider})
    FakeProvider.reset(pid)

    cascade_config = [providers: [FakeProvider], timeout_ms: 1_000]

    on_exit(fn ->
      Application.delete_env(:sovereign_soul_engine, :llm_providers)
    end)

    %{pid: pid, cascade_config: cascade_config}
  end

  describe "cascade routing" do
    test "responds successfully when first provider succeeds", %{cascade_config: cc, pid: pid} do
      FakeProvider.set_fixture(pid, :normal_speech)

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 cc
               )

      assert response.public_speech != ""
      assert response.tone == "cautious"
    end

    test "falls back to next provider on failure", %{pid: pid} do
      FakeProvider.set_fixture(pid, :provider_error)

      assert {:error, _} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )
    end

    test "returns cascade_exhausted when all providers fail", %{pid: pid} do
      FakeProvider.set_fixture(pid, :provider_error)

      assert {:error, reason} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider, FakeProvider, FakeProvider],
                 timeout_ms: 1_000
               )

      assert reason == "cascade_exhausted: all providers failed"
    end

    test "respects custom provider ordering via config", %{pid: pid} do
      Application.put_env(:sovereign_soul_engine, :llm_providers, [FakeProvider])

      FakeProvider.set_fixture(pid, :aggressive_speech)

      assert {:ok, response} =
               ProviderCascade.respond(%{messages: []})

      assert response.tone == "aggressive"

      Application.delete_env(:sovereign_soul_engine, :llm_providers)
    end
  end

  describe "response validation" do
    test "sanitizes missing required fields with defaults", %{pid: pid} do
      FakeProvider.set_raw(pid, {:ok, %{}})

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert response.public_speech == "..."
      assert response.private_thought == ""
      assert response.tone == "neutral"
      assert response.motivation == "unknown"
    end

    test "truncates excessively large string fields", %{pid: pid} do
      large = String.duplicate("X", 50_000)

      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: large,
           private_thought: large,
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert String.length(response.public_speech) <= 20_000
      assert String.length(response.private_thought) <= 20_000
    end

    test "validates and normalizes target_character_id as UUID", %{pid: pid} do
      valid_uuid = "550e8400-e29b-41d4-a716-446655440000"

      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: valid_uuid,
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert response.target_character_id == valid_uuid
    end

    test "rejects non-UUID target_character_id", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: "not-a-uuid",
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert is_nil(response.target_character_id)
    end

    test "clamps confidence to 0.0-1.0 range", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: %{type: "speak", confidence: 1.5, reason: "test"},
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert response.proposed_action.confidence == 1.0
    end

    test "clamps negative confidence to 0.0", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: %{type: "speak", confidence: -0.5, reason: "test"},
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert response.proposed_action.confidence == 0.0
    end

    test "drops proposed_action when type is empty", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: %{type: "", confidence: 0.5, reason: ""},
           memory_candidates: [],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert is_nil(response.proposed_action)
    end

    test "clamps memory importance and emotional_intensity to 0-100", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: [
             %{
               category: "episodic",
               summary: "test",
               importance: 150,
               emotional_intensity: -10,
               valence: 2.5,
               tags: ["test"]
             }
           ],
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      mem = hd(response.memory_candidates)
      assert mem.importance == 100
      assert mem.emotional_intensity == 0
      assert mem.valence == 1.0
    end

    test "handles nil memory_candidates gracefully", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: nil,
           relationship_signals: nil
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert response.memory_candidates == []
    end

    test "converts non-map inputs to error", %{pid: pid} do
      FakeProvider.set_raw(pid, {:ok, "not a map"})

      assert {:error, reason} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert reason =~ "all providers failed"
    end

    test "normalizes relationship_signals string keys to strings", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: %{"trust" => 5, "anger" => -3}
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert is_map(response.relationship_signals)
      assert response.relationship_signals["trust"] == 5
      assert response.relationship_signals["anger"] == -3
    end

    test "converts empty relationship_signals map to nil", %{pid: pid} do
      FakeProvider.set_raw(
        pid,
        {:ok,
         %{
           public_speech: "test",
           private_thought: "test",
           tone: "test",
           motivation: "test",
           target_character_id: nil,
           proposed_action: nil,
           memory_candidates: [],
           relationship_signals: %{}
         }}
      )

      assert {:ok, response} =
               ProviderCascade.respond(
                 %{messages: []},
                 providers: [FakeProvider],
                 timeout_ms: 1_000
               )

      assert is_nil(response.relationship_signals)
    end
  end

  describe "health_all" do
    test "returns health for all configured providers" do
      Application.put_env(:sovereign_soul_engine, :llm_providers, [FakeProvider])

      health = ProviderCascade.health_all()

      assert is_map(health)
      assert {:ok, %{status: "healthy"}} = health["fake"]

      Application.delete_env(:sovereign_soul_engine, :llm_providers)
    end
  end

  describe "configured_providers" do
    test "returns default providers when not configured" do
      Application.delete_env(:sovereign_soul_engine, :llm_providers)

      providers = ProviderCascade.configured_providers()

      assert is_list(providers)
      assert length(providers) == 5
    end

    test "returns configured providers when set" do
      Application.put_env(:sovereign_soul_engine, :llm_providers, [FakeProvider])

      providers = ProviderCascade.configured_providers()

      assert providers == [FakeProvider]
    end
  end
end
