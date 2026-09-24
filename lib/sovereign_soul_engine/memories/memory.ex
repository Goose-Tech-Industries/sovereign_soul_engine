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
    field :valid_from, :utc_datetime_usec
    field :valid_until, :utc_datetime_usec
    field :supersession_reason, :string
    field :provenance, :map, default: %{}

    belongs_to :owner_character, SovereignSoulEngine.Characters.Character
    belongs_to :subject_character, SovereignSoulEngine.Characters.Character
    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :event, SovereignSoulEngine.Scenes.SoulEvent

    belongs_to :consolidated_into, SovereignSoulEngine.Memories.Memory,
      foreign_key: :consolidated_into_id,
      type: :binary_id

    belongs_to :supersedes, SovereignSoulEngine.Memories.Memory, type: :binary_id
    belongs_to :superseded_by, SovereignSoulEngine.Memories.Memory, type: :binary_id

    timestamps()
  end

  @categories ~w(working episodic relationship core wound belief)
  @statuses ~w(active consolidated archived superseded)

  @doc "The exact set of valid memory categories — the LLM boundary (Generator) validates against this before ever building a changeset."
  def categories, do: @categories

  @doc "The exact set of valid memory lifecycle statuses."
  def statuses, do: @statuses

  @doc "Returns true if this memory has been superseded by a newer fact."
  def superseded?(%__MODULE__{status: "superseded"}), do: true
  def superseded?(_), do: false

  @doc "Returns the UUID of the memory that superseded this one, if any."
  def superseded_by_id(%__MODULE__{superseded_by_id: id}) when not is_nil(id), do: id

  def superseded_by_id(%__MODULE__{metadata: %{} = meta}) do
    Map.get(meta, "superseded_by_id") || Map.get(meta, :superseded_by_id)
  end

  def superseded_by_id(_), do: nil

  @doc "Returns the UUID of the memory that this one superseded, if any."
  def supersedes_id(%__MODULE__{supersedes_id: id}) when not is_nil(id), do: id

  def supersedes_id(%__MODULE__{metadata: %{} = meta}) do
    Map.get(meta, "supersedes_id") || Map.get(meta, :supersedes_id)
  end

  def supersedes_id(_), do: nil

  @doc "Returns the timestamp when this fact became valid (defaults to occurred_at)."
  def valid_from(%__MODULE__{valid_from: valid_from}) when not is_nil(valid_from), do: valid_from

  def valid_from(%__MODULE__{metadata: %{} = meta, occurred_at: occurred_at}) do
    Map.get(meta, "valid_from") || Map.get(meta, :valid_from) || occurred_at
  end

  def valid_from(_), do: nil

  @doc "Returns the timestamp when this fact ceased being valid, if superseded."
  def valid_until(%__MODULE__{valid_until: valid_until}) when not is_nil(valid_until),
    do: valid_until

  def valid_until(%__MODULE__{metadata: %{} = meta}) do
    Map.get(meta, "valid_until") || Map.get(meta, :valid_until)
  end

  def valid_until(_), do: nil

  @doc "Returns provenance metadata indicating how this memory was acquired (witnessed, told_by, rumor, inferred)."
  def provenance(%__MODULE__{provenance: provenance})
      when is_map(provenance) and map_size(provenance) > 0,
      do: provenance

  def provenance(%__MODULE__{metadata: %{} = meta}) do
    Map.get(meta, "provenance") || Map.get(meta, :provenance) || %{}
  end

  def provenance(_), do: %{}

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
      :consolidated_into_id,
      :supersedes_id,
      :superseded_by_id,
      :valid_from,
      :valid_until,
      :supersession_reason,
      :provenance
    ])
    |> validate_required([:owner_character_id, :category, :summary, :occurred_at])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:status, @statuses)
  end
end
