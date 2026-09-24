defmodule SovereignSoulEngine.Safety.GroundingTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Safety.Grounding

  test "requires explicit opt in" do
    assert {:error, :not_enabled} = Grounding.plan(%{})
  end

  test "builds sensory grounding without diagnosing" do
    assert {:ok, plan} =
             Grounding.plan(%{
               grounding_enabled: true,
               style: :sensory,
               statement: "The voices are frightening"
             })

    assert length(plan.steps) == 5
    assert plan.reality_anchor =~ "cannot verify"
    refute plan.escalate
  end

  test "uses a trusted adult path for minors" do
    assert {:ok, plan} = Grounding.plan(%{grounding_enabled: true, age_group: :minor})
    assert plan.trusted_adult_required
    assert plan.escalation_message == nil
  end

  test "escalates explicit danger signals" do
    assert {:ok, plan} = Grounding.plan(%{grounding_enabled: true, safety_signal: "self_harm"})
    assert plan.escalate
    assert plan.escalation_message =~ "trusted"
  end

  test "supports breathing and direct styles" do
    assert {:ok, breathing} = Grounding.plan(%{grounding_enabled: true, style: "breathing"})
    assert "Breathe out slowly and let your shoulders drop." in breathing.steps
    assert {:ok, direct} = Grounding.plan(%{grounding_enabled: true, style: "direct"})
    assert "Check the date and time." in direct.steps
  end

  test "unknown styles safely use gentle defaults" do
    assert {:ok, plan} = Grounding.plan(%{grounding_enabled: true, style: "unknown"})
    assert plan.style == "gentle"
  end

  test "reality anchor stays supportive without confirming a claim" do
    anchor = Grounding.reality_anchor("Someone is sending me secret messages")
    assert anchor =~ "feels real"
    assert anchor =~ "cannot verify"
  end

  test "minor danger calls for trusted adult and emergency support" do
    assert {:ok, plan} =
             Grounding.plan(%{
               grounding_enabled: true,
               age_group: "child",
               immediate_danger: true
             })

    assert plan.trusted_adult_required
    assert plan.escalation_message =~ "emergency"
  end
end
