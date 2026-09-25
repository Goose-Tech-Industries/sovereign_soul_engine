defmodule SovereignSoulEngine.SecretsTriggersChangesetsTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Secrets.CharacterSecret
  alias SovereignSoulEngine.Triggers.CharacterTrigger

  test "character secrets validate required fields and risk levels" do
    assert %{character_id: ["can't be blank"], secret_text: ["can't be blank"]} =
             errors(CharacterSecret.changeset(%CharacterSecret{}, %{}))

    assert %{risk_level: ["is invalid"]} =
             errors(
               CharacterSecret.changeset(%CharacterSecret{}, %{
                 character_id: Ecto.UUID.generate(),
                 secret_text: "x",
                 risk_level: "unknown"
               })
             )
  end

  test "character triggers validate required fields and reaction types" do
    assert %{topic: ["can't be blank"]} =
             errors(
               CharacterTrigger.changeset(%CharacterTrigger{}, %{
                 character_id: Ecto.UUID.generate(),
                 reaction_type: "anger_spike"
               })
             )

    assert %{reaction_type: ["is invalid"]} =
             errors(
               CharacterTrigger.changeset(%CharacterTrigger{}, %{
                 character_id: Ecto.UUID.generate(),
                 topic: "x",
                 reaction_type: "unknown"
               })
             )
  end

  defp errors(changeset), do: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
end
