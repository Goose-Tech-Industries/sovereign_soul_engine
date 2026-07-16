defmodule SovereignSoulEngine.Ledger do
  @moduledoc """
  Context for managing the Soul Ledger — immutable explanation timeline for all canonical mutations.
  """

  alias SovereignSoulEngine.Ledger.SoulLedger
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_entries do
    Repo.all(from e in SoulLedger, order_by: [desc: :inserted_at])
  end

  def get_entry!(id), do: Repo.get!(SoulLedger, id)

  def list_entries_for_character(character_id) do
    Repo.all(
      from e in SoulLedger,
        where: e.character_id == ^character_id,
        order_by: [desc: :inserted_at]
    )
  end

  def list_entries_for_scene(scene_id) do
    Repo.all(
      from e in SoulLedger,
        where: e.scene_id == ^scene_id,
        order_by: [asc: :inserted_at]
    )
  end

  def list_entries_by_correlation(correlation_id) do
    Repo.all(
      from e in SoulLedger,
        where: e.correlation_id == ^correlation_id,
        order_by: [asc: :inserted_at]
    )
  end

  def create_entry(attrs \\ %{}) do
    %SoulLedger{}
    |> SoulLedger.changeset(attrs)
    |> Repo.insert()
  end
end
