defmodule SovereignSoulEngine.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenants" do
    field :name, :string
    field :external_source, :string
    field :api_key_hash, :string
    field :api_key_prefix, :string
    field :rate_limit_per_minute, :integer, default: 60
    field :llm_call_count, :integer, default: 0
    field :active, :boolean, default: true
    field :byok_provider, :string
    field :byok_api_key_encrypted, :binary

    timestamps()
  end

  @byok_providers ~w(anthropic openai deepseek xai gemini)

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :external_source, :api_key_hash, :api_key_prefix, :rate_limit_per_minute, :active])
    |> validate_required([:name, :external_source, :api_key_hash, :api_key_prefix])
    |> validate_number(:rate_limit_per_minute, greater_than: 0)
    |> unique_constraint(:external_source)
    |> unique_constraint(:api_key_hash)
  end

  def byok_changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:byok_provider, :byok_api_key_encrypted])
    |> validate_inclusion(:byok_provider, @byok_providers)
  end

  def clear_byok_changeset(tenant) do
    change(tenant, byok_provider: nil, byok_api_key_encrypted: nil)
  end
end
