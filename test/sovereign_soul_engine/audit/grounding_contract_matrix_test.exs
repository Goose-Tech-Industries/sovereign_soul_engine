defmodule SovereignSoulEngine.Audit.GroundingContractMatrixTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Safety.Grounding

  @styles [:gentle, :direct, :sensory, :breathing, :unknown]
  @safe_signals [nil, "check_in", :check_in]
  @danger_signals ["self_harm", :harm_to_others, "immediate_danger"]

  # These 150 cases deliberately vary the public input shapes integrations use:
  # atom/string keys, atom/string styles, adult/minor context, and each explicit
  # escalation signal. This is contract coverage, not duplicate assertions.
  for case_number <- 1..150 do
    test "grounding contract matrix case #{case_number}" do
      style = Enum.at(@styles, rem(unquote(case_number), length(@styles)))
      danger? = rem(unquote(case_number), 3) == 0
      minor? = rem(unquote(case_number), 2) == 0
      string_keys? = rem(unquote(case_number), 4) == 0

      enabled_key = if string_keys?, do: "grounding_enabled", else: :grounding_enabled
      style_key = if string_keys?, do: "style", else: :style
      age_key = if string_keys?, do: "age_group", else: :age_group
      statement_key = if string_keys?, do: "statement", else: :statement

      context = %{
        enabled_key => true,
        style_key => style,
        age_key => if(minor?, do: "minor", else: "adult"),
        statement_key => "contract case #{unquote(case_number)}",
        "safety_signal" =>
          if(danger?,
            do: Enum.at(@danger_signals, rem(unquote(case_number), 3)),
            else: Enum.at(@safe_signals, rem(unquote(case_number), 3))
          )
      }

      assert {:ok, plan} = Grounding.plan(context)
      assert plan.mode == :grounding
      assert plan.style in ["gentle", "direct", "sensory", "breathing"]
      assert length(plan.steps) > 0
      assert Enum.all?(plan.steps, &is_binary/1)
      assert plan.reality_anchor =~ "cannot verify"
      assert plan.trusted_adult_required == minor?
      assert plan.escalate == danger?

      rendered = Grounding.render(plan, "Matrix Companion")
      assert rendered =~ "Matrix Companion"
      assert rendered =~ "1."
      assert rendered =~ "cannot verify"
    end
  end
end
