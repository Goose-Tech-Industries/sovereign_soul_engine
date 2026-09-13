defmodule SovereignSoulEngine.TheoryOfMind.LifeThread do
  @moduledoc """
  Schema for tracking unresolved, open real-world or narrative life threads
  (e.g., proposals, interviews, surgeries, major vulnerabilities) that require
  proactive follow-up and empathetic continuity.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "character_life_threads" do
    field :topic, :string
    field :category, :string, default: "milestone"
    field :status, :string, default: "pending"
    field :salience, :integer, default: 70
    field :due_at, :utc_datetime_usec
    field :check_in_sent_at, :utc_datetime_usec
    field :check_in_guidance, :string
    field :resolution_notes, :string

    belongs_to :knower_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :knower_character_id

    belongs_to :subject_character, SovereignSoulEngine.Characters.Character,
      foreign_key: :subject_character_id

    timestamps(type: :utc_datetime_usec)
  end

  @categories ~w(milestone stressor health career relationship personal_vulnerability)
  @statuses ~w(pending resolved dismissed)

  def changeset(life_thread, attrs) do
    life_thread
    |> cast(attrs, [
      :knower_character_id,
      :subject_character_id,
      :topic,
      :category,
      :status,
      :salience,
      :due_at,
      :check_in_sent_at,
      :check_in_guidance,
      :resolution_notes
    ])
    |> validate_required([:knower_character_id, :subject_character_id, :topic])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:salience, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
