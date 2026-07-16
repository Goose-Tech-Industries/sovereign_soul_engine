defmodule SovereignSoulEngine.Memories do
  @moduledoc """
  Context for managing Memories — episodic, core, wound, belief, relationship, and working memories.
  """

  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_memories do
    Repo.all(Memory)
  end

  def get_memory!(id), do: Repo.get!(Memory, id)

  def list_memories_for_character(character_id) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id,
        order_by: [desc: m.importance]
    )
  end

  def list_memories_by_category(character_id, category) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.category == ^category,
        order_by: [desc: m.importance]
    )
  end

  def list_unresolved_memories(character_id) do
    Repo.all(
      from m in Memory,
        where: m.owner_character_id == ^character_id and m.is_resolved == false,
        order_by: [desc: m.importance, desc: m.emotional_intensity]
    )
  end

  def create_memory(attrs \\ %{}) do
    %Memory{}
    |> Memory.changeset(attrs)
    |> Repo.insert()
  end

  def update_memory(%Memory{} = memory, attrs) do
    memory
    |> Memory.changeset(attrs)
    |> Repo.update()
  end

  def delete_memory(%Memory{} = memory) do
    Repo.delete(memory)
  end

  def change_memory(%Memory{} = memory, attrs \\ %{}) do
    Memory.changeset(memory, attrs)
  end
end
