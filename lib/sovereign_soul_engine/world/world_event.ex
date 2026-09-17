defmodule SovereignSoulEngine.World.WorldEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  An append-only, signed event on the Soul Society world ledger (RFC-0002 §6.3).

  Only *memorable* outcomes are appended; continuous turn chatter is transient
  and never touches this table.
  """

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "world_events" do
    field :kind, :string
    field :from_did, :string
    field :to_did, :string
    field :payload, :map, default: %{}
    field :signature, :string
    field :retained_until, :utc_datetime
    field :compacted, :boolean, default: false

    timestamps()
  end

  @kinds ~w(presence encounter gossip world_post world_summary)

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:kind, :from_did, :to_did, :payload, :signature, :retained_until, :compacted])
    |> validate_required([:kind])
    |> validate_inclusion(:kind, @kinds)
  end
end
