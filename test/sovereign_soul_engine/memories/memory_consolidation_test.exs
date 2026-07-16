defmodule SovereignSoulEngine.Memories.MemoryConsolidationTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Memories.MemoryConsolidation

  describe "promotion to belief" do
    test "core memory with high recall count promotes to belief" do
      memory = %{
        category: :core,
        recall_count: 12,
        importance: 95
      }

      results = MemoryConsolidation.evaluate(memory)

      assert [{:promote, :belief, reason}] = results
      assert reason =~ "belief"
    end

    test "core memory with insufficient recall does not promote" do
      memory = %{
        category: :core,
        recall_count: 5,
        importance: 95
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :belief end)
    end

    test "non-core memory does not promote to belief regardless of recall" do
      memory = %{
        category: :episodic,
        recall_count: 20,
        importance: 80
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :belief end)
    end
  end

  describe "promotion to core" do
    test "high importance episodic promotes to core" do
      memory = %{
        category: :episodic,
        importance: 95,
        recall_count: 3
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.any?(results, fn {:promote, :core, reason} ->
               reason =~ "core memory"
             end)
    end

    test "importance below threshold does not promote" do
      memory = %{
        category: :episodic,
        importance: 80,
        recall_count: 10
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :core end)
    end

    test "already core memory does not promote to core again" do
      memory = %{
        category: :core,
        importance: 99,
        recall_count: 1
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :core end)
    end

    test "belief memory does not promote to core" do
      memory = %{
        category: :belief,
        importance: 99,
        recall_count: 1
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :core end)
    end
  end

  describe "promotion to wound" do
    test "harmful event with high emotional intensity promotes to wound" do
      memory = %{
        category: :episodic,
        emotional_intensity: 90,
        importance: 75,
        recall_count: 2,
        valence: -0.8
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :betrayed_me)

      assert Enum.any?(results, fn {:promote, :wound, reason} ->
               reason =~ "wound"
             end)
    end

    test "non-harmful event does not create wound even with high intensity" do
      memory = %{
        category: :episodic,
        emotional_intensity: 90,
        importance: 75,
        recall_count: 2,
        valence: -0.8
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :praised_me)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :wound end)
    end

    test "low emotional intensity harmful event does not create wound" do
      memory = %{
        category: :episodic,
        emotional_intensity: 50,
        importance: 75,
        recall_count: 2,
        valence: -0.8
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :betrayed_me)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :wound end)
    end

    test "positive valence on harmful event does not create wound" do
      memory = %{
        category: :episodic,
        emotional_intensity: 90,
        importance: 75,
        recall_count: 2,
        valence: 0.5
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :attacked_me)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :wound end)
    end

    test "already wound memory does not promote to wound again" do
      memory = %{
        category: :wound,
        emotional_intensity: 95,
        importance: 80,
        valence: -0.9
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :betrayed_me)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :wound end)
    end
  end

  describe "promotion to relationship" do
    test "repeated episodic memory promotes to relationship" do
      memory = %{
        category: :episodic,
        recall_count: 8,
        importance: 80,
        emotional_intensity: 60
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.any?(results, fn {:promote, :relationship, reason} ->
               reason =~ "relationship"
             end)
    end

    test "low recall count does not promote to relationship" do
      memory = %{
        category: :episodic,
        recall_count: 3,
        importance: 80,
        emotional_intensity: 60
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :relationship end)
    end

    test "low importance does not promote to relationship" do
      memory = %{
        category: :episodic,
        recall_count: 8,
        importance: 60,
        emotional_intensity: 60
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :relationship end)
    end

    test "already relationship memory does not promote again" do
      memory = %{
        category: :relationship,
        recall_count: 15,
        importance: 90
      }

      results = MemoryConsolidation.evaluate(memory)

      assert Enum.all?(results, fn {:promote, cat, _} -> cat != :relationship end)
    end
  end

  describe "multiple promotions" do
    test "a single memory can receive multiple promotion recommendations" do
      memory = %{
        category: :episodic,
        recall_count: 10,
        importance: 95,
        emotional_intensity: 90,
        valence: -0.8
      }

      results = MemoryConsolidation.evaluate(memory, event_type: :betrayed_me)

      categories = Enum.map(results, fn {:promote, cat, _} -> cat end)

      assert :wound in categories
      assert :core in categories
      assert :relationship in categories
    end
  end

  describe "contradictory detection" do
    test "memories with same event_id and opposing valence are contradictory" do
      a = %{event_id: Ecto.UUID.generate(), valence: 0.8}
      b = %{event_id: a.event_id, valence: -0.8}

      assert MemoryConsolidation.contradictory?(a, b)
    end

    test "memories with same event_id and same valence direction are not contradictory" do
      a = %{event_id: Ecto.UUID.generate(), valence: 0.8}
      b = %{event_id: a.event_id, valence: 0.5}

      refute MemoryConsolidation.contradictory?(a, b)
    end

    test "memories with different event_id are not contradictory" do
      a = %{event_id: Ecto.UUID.generate(), valence: 0.8}
      b = %{event_id: Ecto.UUID.generate(), valence: -0.8}

      refute MemoryConsolidation.contradictory?(a, b)
    end

    test "memories without event_id are not contradictory" do
      a = %{event_id: nil, valence: 0.8}
      b = %{event_id: nil, valence: -0.8}

      refute MemoryConsolidation.contradictory?(a, b)
    end

    test "neutral valence near zero is not contradictory" do
      a = %{event_id: Ecto.UUID.generate(), valence: 0.05}
      b = %{event_id: a.event_id, valence: -0.05}

      refute MemoryConsolidation.contradictory?(a, b)
    end
  end

  describe "no promotions" do
    test "returns empty list for ordinary episodic memory" do
      memory = %{
        category: :episodic,
        importance: 30,
        recall_count: 2,
        emotional_intensity: 30
      }

      results = MemoryConsolidation.evaluate(memory)

      assert results == []
    end
  end
end
