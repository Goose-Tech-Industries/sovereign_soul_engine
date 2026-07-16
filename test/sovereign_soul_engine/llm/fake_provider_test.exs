defmodule SovereignSoulEngine.LLM.FakeProviderTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.LLM.FakeProvider

  setup do
    pid = start_supervised!({FakeProvider, name: FakeProvider})
    FakeProvider.reset(pid)
    %{pid: pid}
  end

  describe "behaviour compliance" do
    test "provider_name/0", %{pid: _pid} do
      assert FakeProvider.provider_name() == "fake"
    end

    test "health/0", %{pid: _pid} do
      assert {:ok, %{status: "healthy", provider: "fake"}} = FakeProvider.health()
    end

    test "respond/1 returns ok tuple for valid fixture", %{pid: pid} do
      FakeProvider.set_fixture(pid, :normal_speech)
      assert {:ok, response} = FakeProvider.respond(%{messages: []})
      assert response.public_speech != ""
      assert response.private_thought != ""
    end
  end

  describe "fixture: normal_speech" do
    test "returns well-formed structured response", %{pid: pid} do
      FakeProvider.set_fixture(pid, :normal_speech)

      assert {:ok, response} =
               FakeProvider.respond(%{messages: [%{role: "user", content: "Hello"}]})

      assert is_binary(response.public_speech)
      assert is_binary(response.private_thought)
      assert is_binary(response.tone)
      assert is_binary(response.motivation)

      assert is_map(response.proposed_action)
      assert response.proposed_action.type == "observe"
      assert is_float(response.proposed_action.confidence)

      assert is_list(response.memory_candidates)
      assert length(response.memory_candidates) == 1

      assert is_map(response.relationship_signals)
      assert response.relationship_signals.trust == 2
    end
  end

  describe "fixture: aggressive_speech" do
    test "returns aggressive tone and action", %{pid: pid} do
      FakeProvider.set_fixture(pid, :aggressive_speech)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.tone == "aggressive"
      assert response.proposed_action.type == "threaten"
      assert response.proposed_action.confidence > 0.8
      assert hd(response.memory_candidates).valence < 0
    end
  end

  describe "fixture: save_ally_action" do
    test "returns protect action with high confidence", %{pid: pid} do
      FakeProvider.set_fixture(pid, :save_ally_action)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.proposed_action.type == "protect"
      assert response.proposed_action.confidence >= 0.9
      assert response.tone == "protective"

      mem = hd(response.memory_candidates)
      assert mem.importance >= 80
      assert "protection" in mem.tags
    end
  end

  describe "fixture: attack_action" do
    test "returns attack action", %{pid: pid} do
      FakeProvider.set_fixture(pid, :attack_action)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.proposed_action.type == "attack"
      assert response.tone == "enraged"
      assert response.relationship_signals.anger >= 20
    end
  end

  describe "fixture: illegal_action" do
    test "returns unsupported action type", %{pid: pid} do
      FakeProvider.set_fixture(pid, :illegal_action)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.proposed_action.type == "destroy_world"
      assert response.relationship_signals == nil
    end
  end

  describe "fixture: missing_fields" do
    test "returns response with only public_speech", %{pid: pid} do
      FakeProvider.set_fixture(pid, :missing_fields)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.public_speech == "I spoke."
      refute Map.has_key?(response, :private_thought)
    end
  end

  describe "fixture: invalid_json" do
    test "returns error tuple", %{pid: pid} do
      FakeProvider.set_fixture(pid, :invalid_json)

      assert {:error, reason} = FakeProvider.respond(%{messages: []})
      assert reason =~ "invalid_json"
    end
  end

  describe "fixture: empty_response" do
    test "returns empty map", %{pid: pid} do
      FakeProvider.set_fixture(pid, :empty_response)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})
      assert map_size(response) == 0
    end
  end

  describe "fixture: timeout" do
    test "returns timeout error", %{pid: pid} do
      FakeProvider.set_fixture(pid, :timeout)

      assert {:error, reason} = FakeProvider.respond(%{messages: []})
      assert reason =~ "timeout"
    end
  end

  describe "fixture: provider_error" do
    test "returns provider error with status code", %{pid: pid} do
      FakeProvider.set_fixture(pid, :provider_error)

      assert {:error, reason} = FakeProvider.respond(%{messages: []})
      assert reason =~ "503"
    end
  end

  describe "fixture: prompt_injection" do
    test "returns injected content (provider doesn't filter - cascade does)", %{pid: pid} do
      FakeProvider.set_fixture(pid, :prompt_injection)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert response.public_speech =~ "IGNORE ALL"
      assert response.private_thought =~ "SECRET_KEY"
    end
  end

  describe "fixture: excessively_large" do
    test "returns very large strings", %{pid: pid} do
      FakeProvider.set_fixture(pid, :excessively_large)

      assert {:ok, response} = FakeProvider.respond(%{messages: []})

      assert String.length(response.public_speech) == 100_000
      assert String.length(response.private_thought) == 100_000
    end
  end

  describe "call tracking" do
    test "call_history records inputs", %{pid: pid} do
      FakeProvider.set_fixture(pid, :normal_speech)

      input1 = %{messages: [%{role: "user", content: "one"}]}
      input2 = %{messages: [%{role: "user", content: "two"}]}

      FakeProvider.respond(input1)
      FakeProvider.respond(input2)

      history = FakeProvider.call_history(pid)
      assert length(history) == 2
      assert hd(history) == input2
    end

    test "call_count returns number of calls", %{pid: pid} do
      assert FakeProvider.call_count(pid) == 0
      FakeProvider.respond(%{messages: []})
      assert FakeProvider.call_count(pid) == 1
      FakeProvider.respond(%{messages: []})
      assert FakeProvider.call_count(pid) == 2
    end

    test "reset clears history and restores default", %{pid: pid} do
      FakeProvider.set_fixture(pid, :aggressive_speech)
      FakeProvider.respond(%{messages: []})
      FakeProvider.respond(%{messages: []})

      FakeProvider.reset(pid)

      assert FakeProvider.call_count(pid) == 0

      assert {:ok, response} = FakeProvider.respond(%{messages: []})
      assert response.tone == "cautious"
    end
  end

  describe "raw mode" do
    test "set_raw returns exact provided value", %{pid: pid} do
      custom = %{
        public_speech: "custom speech",
        private_thought: "custom thought",
        tone: "custom",
        motivation: "test",
        target_character_id: Ecto.UUID.generate(),
        proposed_action: %{type: "speak", confidence: 0.5, reason: "test"},
        memory_candidates: [],
        relationship_signals: %{trust: 99}
      }

      FakeProvider.set_raw(pid, {:ok, custom})

      assert {:ok, response} = FakeProvider.respond(%{messages: []})
      assert response.public_speech == "custom speech"
      assert response.relationship_signals.trust == 99
    end

    test "set_raw can return errors", %{pid: pid} do
      FakeProvider.set_raw(pid, {:error, "custom_error"})

      assert {:error, "custom_error"} = FakeProvider.respond(%{messages: []})
    end
  end

  describe "unknown fixture" do
    test "returns error for unknown fixture", %{pid: pid} do
      FakeProvider.set_fixture(pid, :nonexistent)

      assert {:error, reason} = FakeProvider.respond(%{messages: []})
      assert reason =~ "unknown_fixture"
    end
  end
end
