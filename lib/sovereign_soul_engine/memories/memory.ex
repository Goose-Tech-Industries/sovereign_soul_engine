defmodule SovereignSoulEngine.Memories.Memory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memories" do
    field :category, :string
    field :summary, :string
    field :details, :map, default: %{}
    field :importance, :integer, default: 1
    field :emotional_intensity, :integer, default: 0
    field :confidence, :integer, default: 100
    field :valence, :float, default: 0.0
    field :tags, {:array, :string}, default: []
    field :emotional_residue, :map, default: %{}
    field :occurred_at, :utc_datetime_usec
    field :last_recalled_at, :utc_datetime_usec
    field :recall_count, :integer, default: 0
    field :decay_rate, :float, default: 1.0
    field :is_resolved, :boolean, default: false
    field :metadata, :map, default: %{}
    field :status, :string, default: "active"

    belongs_to :owner_character, SovereignSoulEngine.Characters.Character
    belongs_to :subject_character, SovereignSoulEngine.Characters.Character
    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :event, SovereignSoulEngine.Scenes.SoulEvent
    belongs_to :consolidated_into, SovereignSoulEngine.Memories.Memory,
      foreign_key: :consolidated_into_id, type: :binary_id

    timestamps()
  end

  @categories ~w(working episodic relationship core wound belief)
  @statuses ~w(active consolidated archived)

  @doc "The exact set of valid memory categories — the LLM boundary (Generator) validates against this before ever building a changeset."
  def categories, do: @categories

  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [
      :owner_character_id,
      :subject_character_id,
      :scene_id,
      :event_id,
      :category,
      :summary,
      :details,
      :importance,
      :emotional_intensity,
      :confidence,
      :valence,
      :tags,
      :emotional_residue,
      :occurred_at,
      :last_recalled_at,
      :recall_count,
      :decay_rate,
      :is_resolved,
      :metadata,
      :status,
      :consolidated_into_id
    ])
    |> validate_required([:owner_character_id, :category, :summary, :occurred_at])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:status, @statuses)
  end
end
