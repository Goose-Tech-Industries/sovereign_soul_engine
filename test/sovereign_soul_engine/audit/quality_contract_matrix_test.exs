defmodule SovereignSoulEngine.Audit.QualityContractMatrixTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.Crypto.{Base58, CanonicalJSON}
  alias SovereignSoulEngine.Safety.Grounding
  alias SovereignSoulEngine.Souls.Neurochemistry
  alias SovereignSoulEngine.Wearables.HapticEngine
  alias SovereignSoulEngine.World.Lorebook

  @styles [:gentle, :direct, :sensory, :breathing]
  @patterns [:heartbeat, :panic_flutter, :calming_cadence, :intimacy_warmth, :alert_ping]

  # A deterministic cross-domain contract matrix. Every case changes the
  # input vector and exercises one public boundary; this is deliberately kept
  # database- and network-free so it remains reliable in CI.
  for case_number <- 1..831 do
    test "quality contract case #{case_number}" do
      mode = rem(unquote(case_number), 7)

      case mode do
        0 ->
          bytes =
            0..rem(unquote(case_number), 16)
            |> Enum.map(&rem(&1 * unquote(case_number), 256))
            |> :binary.list_to_bin()

          encoded = Base58.encode(bytes)
          assert {:ok, ^bytes} = Base58.decode(encoded)

        1 ->
          value = %{
            "case" => unquote(case_number),
            "active" => rem(unquote(case_number), 2) == 0,
            "nested" => %{"slug" => "quality-#{unquote(case_number)}"}
          }

          encoded = CanonicalJSON.encode(value)
          assert encoded =~ "\"case\":#{unquote(case_number)}"
          assert encoded == CanonicalJSON.encode(value)

        2 ->
          action =
            Enum.at(
              ActionIntent.action_types(),
              rem(unquote(case_number), length(ActionIntent.action_types()))
            )

          changeset =
            ActionIntent.changeset(%ActionIntent{}, %{
              scene_id: Ecto.UUID.generate(),
              character_id: Ecto.UUID.generate(),
              proposed_action: action,
              proposed_confidence: rem(unquote(case_number), 101) / 100,
              validation_status: "pending"
            })

          assert changeset.valid?
          assert Ecto.Changeset.get_field(changeset, :proposed_action) == action

        3 ->
          style = Enum.at(@styles, rem(unquote(case_number), length(@styles)))

          assert {:ok, plan} =
                   Grounding.plan(%{
                     grounding_enabled: true,
                     style: style,
                     statement: "quality case #{unquote(case_number)}"
                   })

          assert plan.mode == :grounding
          assert plan.style in ["gentle", "direct", "sensory", "breathing"]
          assert length(plan.steps) > 0
          assert Grounding.render(plan, "Quality Companion") =~ "Quality Companion"

        4 ->
          level = rem(unquote(case_number) * 7, 101)

          result =
            Neurochemistry.compute(
              %{
                stress: level,
                fear: level,
                anger: level,
                attachment: level,
                curiosity: level,
                confidence: level
              },
              %{pain: level, fatigue: level},
              %{wound: level, trust: level, gratitude: level}
            )

          assert result.cortisol in 0..100
          assert result.oxytocin in 0..100
          assert result.dopamine in 0..100
          assert result.serotonin in 0..100
          assert is_binary(result.hormonal_tone)

        5 ->
          level = rem(unquote(case_number) * 11, 101)

          signal =
            HapticEngine.compute(
              %{stress: level, fear: level, attachment: level},
              %{fatigue: level},
              %{cortisol: level, oxytocin: level, dopamine: level}
            )

          assert signal.pattern in @patterns
          assert signal.bpm > 0
          assert length(signal.pulses) > 0
          assert signal.intensity in 0..100

        6 ->
          entries = Lorebook.canonical_entries()
          entry = Enum.at(entries, rem(unquote(case_number), length(entries)))
          rendered = Lorebook.prompt_directive([entry])

          assert rendered =~ "LOREBOOK (WORLD CONTEXT):"
          assert rendered =~ entry.title
          assert rendered =~ entry.content
      end
    end
  end
end
