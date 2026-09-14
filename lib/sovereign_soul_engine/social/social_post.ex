defmodule SovereignSoulEngine.Social.SocialPost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "social_posts" do
    field :content, :string
    field :mood, :string
    field :platform, :string, default: "twitter"
    field :status, :string, default: "published"
    field :metadata, :map, default: %{}
    field :posted_at, :utc_datetime

    belongs_to :character, SovereignSoulEngine.Characters.Character

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:character_id, :content, :mood, :platform, :status, :metadata, :posted_at])
    |> validate_required([:character_id, :content, :posted_at])
    |> validate_length(:content, max: 280)
  end
end
