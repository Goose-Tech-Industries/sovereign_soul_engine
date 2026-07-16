defmodule SovereignSoulEngine.Ledger.SoulLedger do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "soul_ledger" do
    field :entry_type, :string
    field :source, :string
    field :label, :string
    field :summary, :string
    field :before_state, :map, default: %{}
    field :delta, :map, default: %{}
    field :after_state, :map, default: %{}
    field :reason, :string
    field :tags, {:array, :string}, default: []
    field :correlation_id, :binary_id

    belongs_to :character, SovereignSoulEngine.Characters.Character
    belongs_to :scene, SovereignSoulEngine.Scenes.Scene
    belongs_to :event, SovereignSoulEngine.Scenes.SoulEvent
    belongs_to :relationship, SovereignSoulEngine.Relationships.Relationship
    belongs_to :memory, SovereignSoulEngine.Memories.Memory

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @entry_types ~w(
    emotion_change relationship_change memory_created memory_recalled
    memory_resolved memory_promoted action_proposed action_validated
    action_resolved action_rejected event_injected scene_created
    scene_closed character_created soul_profile_updated wound_created
    scene_message_created
  )

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :character_id,
      :scene_id,
      :event_id,
      :relationship_id,
      :memory_id,
      :entry_type,
      :source,
      :label,
      :summary,
      :before_state,
      :delta,
      :after_state,
      :reason,
      :tags,
      :correlation_id
    ])
    |> validate_required([:character_id, :entry_type, :source, :summary])
    |> validate_inclusion(:entry_type, @entry_types)
  end
end
