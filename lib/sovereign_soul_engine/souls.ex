defmodule SovereignSoulEngine.Souls do
  @moduledoc """
  Context for managing Soul Profiles and Emotional States.
  """

  alias SovereignSoulEngine.Souls.{SoulProfile, EmotionalState, SoulShadow, SoulFear}
  alias SovereignSoulEngine.Repo

  # Soul Profiles

  def get_soul_profile!(id), do: Repo.get!(SoulProfile, id)

  def get_soul_profile_by_character(character_id) do
    Repo.get_by(SoulProfile, character_id: character_id)
  end

  def get_soul_profile_by_character!(character_id) do
    Repo.get_by!(SoulProfile, character_id: character_id)
  end

  def create_soul_profile(attrs \\ %{}) do
    %SoulProfile{}
    |> SoulProfile.changeset(attrs)
    |> Repo.insert()
  end

  def update_soul_profile(%SoulProfile{} = profile, attrs) do
    profile
    |> SoulProfile.changeset(attrs)
    |> Repo.update()
  end

  def change_soul_profile(%SoulProfile{} = profile, attrs \\ %{}) do
    SoulProfile.changeset(profile, attrs)
  end

  # Emotional States

  def get_emotional_state!(id), do: Repo.get!(EmotionalState, id)

  def get_emotional_state_by_character(character_id) do
    Repo.get_by(EmotionalState, character_id: character_id)
  end

  def get_emotional_state_by_character!(character_id) do
    Repo.get_by!(EmotionalState, character_id: character_id)
  end

  def create_emotional_state(attrs \\ %{}) do
    %EmotionalState{}
    |> EmotionalState.changeset(attrs)
    |> Repo.insert()
  end

  def update_emotional_state(%EmotionalState{} = state, attrs) do
    state
    |> EmotionalState.changeset(attrs)
    |> Repo.update()
  end

  def change_emotional_state(%EmotionalState{} = state, attrs \\ %{}) do
    EmotionalState.changeset(state, attrs)
  end

  # Soul Shadows

  def create_soul_shadow(attrs \\ %{}) do
    %SoulShadow{}
    |> SoulShadow.changeset(attrs)
    |> Repo.insert()
  end

  def list_soul_shadows_for_character(character_id) do
    import Ecto.Query
    Repo.all(
      from s in SoulShadow,
        where: s.character_id == ^character_id,
        order_by: [desc: s.inserted_at]
    )
  end

  # Soul Fears

  def create_soul_fear(attrs \\ %{}) do
    %SoulFear{}
    |> SoulFear.changeset(attrs)
    |> Repo.insert()
  end

  def list_soul_fears_for_character(character_id) do
    import Ecto.Query
    Repo.all(
      from f in SoulFear,
        where: f.character_id == ^character_id and f.status == "active",
        order_by: [desc: f.inserted_at]
    )
  end

  def update_soul_fear(%SoulFear{} = soul_fear, attrs) do
    soul_fear
    |> SoulFear.changeset(attrs)
    |> Repo.update()
  end
end
