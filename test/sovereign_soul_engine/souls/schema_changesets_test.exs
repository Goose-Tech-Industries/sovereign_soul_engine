defmodule SovereignSoulEngine.Souls.SchemaChangesetsTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.{
    SomaticState,
    EmotionalState,
    ForgivenessArc,
    GriefArc,
    MoralLine,
    SoulFear,
    SoulShadow,
    SoulProfile
  }
  alias SovereignSoulEngine.Memories.Memory

  @char "11111111-1111-1111-1111-111111111111"
  @scene "22222222-2222-2222-2222-222222222222"

  describe "SomaticState.changeset/2" do
    test "is valid with required fields" do
      assert SomaticState.changeset(%SomaticState{}, %{character_id: @char}).valid?
    end

    test "requires character_id" do
      refute SomaticState.changeset(%SomaticState{}, %{}).valid?
    end

    test "rejects out-of-range hunger" do
      cs = SomaticState.changeset(%SomaticState{}, %{character_id: @char, hunger: 150})
      refute cs.valid?
    end
  end

  describe "EmotionalState.changeset/2" do
    test "is valid with required fields" do
      assert EmotionalState.changeset(%EmotionalState{}, %{character_id: @char}).valid?
    end

    test "rejects out-of-range anger" do
      cs = EmotionalState.changeset(%EmotionalState{}, %{character_id: @char, anger: -5})
      refute cs.valid?
    end

    test "validates every emotional dimension" do
      cs = EmotionalState.changeset(%EmotionalState{}, %{character_id: @char, fear: 200})
      refute cs.valid?
    end
  end

  describe "ForgivenessArc.changeset/2" do
    test "is valid with required fields" do
      attrs = %{character_id: @char, wound_description: "a betrayal"}
      assert ForgivenessArc.changeset(%ForgivenessArc{}, attrs).valid?
    end

    test "requires a wound description" do
      refute ForgivenessArc.changeset(%ForgivenessArc{}, %{character_id: @char}).valid?
    end

    test "rejects an invalid stage" do
      attrs = %{character_id: @char, wound_description: "a", stage: "not-a-stage"}
      refute ForgivenessArc.changeset(%ForgivenessArc{}, attrs).valid?
    end
  end

  describe "GriefArc.changeset/2" do
    test "is valid with required fields" do
      attrs = %{character_id: @char, subject: "their sister", triggered_at: DateTime.utc_now()}
      assert GriefArc.changeset(%GriefArc{}, attrs).valid?
    end

    test "requires triggered_at" do
      attrs = %{character_id: @char, subject: "their sister"}
      refute GriefArc.changeset(%GriefArc{}, attrs).valid?
    end

    test "rejects an invalid loss type" do
      attrs = %{character_id: @char, subject: "x", triggered_at: DateTime.utc_now(), loss_type: "galaxy"}
      refute GriefArc.changeset(%GriefArc{}, attrs).valid?
    end
  end

  describe "MoralLine.changeset/2" do
    test "is valid with required fields" do
      attrs = %{character_id: @char, principle: "Never harm a child"}
      assert MoralLine.changeset(%MoralLine{}, attrs).valid?
    end

    test "requires a principle" do
      refute MoralLine.changeset(%MoralLine{}, %{character_id: @char}).valid?
    end
  end

  describe "SoulFear.changeset/2" do
    test "is valid with required fields" do
      attrs = %{character_id: @char, fear_type: "heights"}
      assert SoulFear.changeset(%SoulFear{}, attrs).valid?
    end

    test "rejects out-of-range severity" do
      attrs = %{character_id: @char, fear_type: "heights", severity: 250}
      refute SoulFear.changeset(%SoulFear{}, attrs).valid?
    end

    test "rejects an invalid origin" do
      attrs = %{character_id: @char, fear_type: "heights", origin: "magic"}
      refute SoulFear.changeset(%SoulFear{}, attrs).valid?
    end
  end

  describe "SoulShadow.changeset/2" do
    test "is valid with required fields" do
      attrs = %{character_id: @char, scene_id: @scene}
      assert SoulShadow.changeset(%SoulShadow{}, attrs).valid?
    end

    test "requires a scene_id" do
      refute SoulShadow.changeset(%SoulShadow{}, %{character_id: @char}).valid?
    end
  end

  describe "SoulProfile.changeset/2" do
    test "is valid with a character_id" do
      assert SoulProfile.changeset(%SoulProfile{}, %{character_id: @char}).valid?
    end

    test "requires character_id" do
      refute SoulProfile.changeset(%SoulProfile{}, %{}).valid?
    end
  end

  describe "Memory.changeset/2" do
    defp memory_attrs do
      %{
        owner_character_id: @char,
        category: "episodic",
        summary: "they shared a meal",
        occurred_at: DateTime.utc_now()
      }
    end

    test "is valid with required fields" do
      assert Memory.changeset(%Memory{}, memory_attrs()).valid?
    end

    test "requires a summary" do
      refute Memory.changeset(%Memory{}, Map.delete(memory_attrs(), :summary)).valid?
    end

    test "rejects an invalid category" do
      refute Memory.changeset(%Memory{}, %{memory_attrs() | category: "banana"}).valid?
    end

    test "rejects an invalid status" do
      attrs = Map.put(memory_attrs(), :status, "lost")
      refute Memory.changeset(%Memory{}, attrs).valid?
    end

    test "exposes the canonical category list" do
      assert "episodic" in Memory.categories()
      assert "wound" in Memory.categories()
    end
  end
end
