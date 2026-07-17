defmodule SovereignSoulEngine.Souls.SoulProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_profiles" do
    field :personality_traits, :map, default: %{}
    field :core_values, {:array, :string}, default: []
    field :fears, {:array, :string}, default: []
    field :desires, {:array, :string}, default: []
    field :speech_style, :string
    field :behavioral_constraints, :map, default: %{}
    field :baseline_emotions, :map, default: %{}
    field :identity_summary, :string
    field :version, :integer, default: 1
    field :attachment_style, :string, default: "secure"
    field :transference_profile, :map, default: %{}
    field :physical_tells, :map, default: %{}
    field :social_stamina, :integer, default: 80
    field :stamina_regen_rate, :integer, default: 10
    field :stamina_max, :integer, default: 100
    field :last_social_action_at, :utc_datetime
    field :emotional_susceptibility, :integer, default: 50
    field :humor_style, :string, default: "none"

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :character_id,
      :personality_traits,
      :core_values,
      :fears,
      :desires,
      :speech_style,
      :behavioral_constraints,
      :baseline_emotions,
      :identity_summary,
      :version,
      :attachment_style,
      :transference_profile,
      :physical_tells,
      :social_stamina,
      :stamina_regen_rate,
      :stamina_max,
      :last_social_action_at,
      :emotional_susceptibility,
      :humor_style
    ])
    |> validate_required([:character_id])
    |> unique_constraint(:character_id)
  end
end
