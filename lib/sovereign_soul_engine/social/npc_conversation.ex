defmodule SovereignSoulEngine.Social.NPCConversation do
  @moduledoc """
  Runs an autonomous NPC-to-NPC conversation.

  Uses the existing Generator with one NPC as "speaker" and the other as
  "interlocutor" (the player-slot). Each Generator call produces a real
  scene message, updates memories, triggers relationship consequences, and
  fires action beats — exactly as if a player were present.

  Conversations are stored in autonomous scenes (is_autonomous: true) so the
  player can discover them later via the social log inspector.

  Stamina cost: each full conversation costs `@stamina_cost` from both NPCs'
  social_stamina pools. Scheduler will not initiate if either NPC is below
  `@stamina_threshold`.
  """

  require Logger

  alias SovereignSoulEngine.{Characters, Scenes, Souls, Repo}
  alias SovereignSoulEngine.Souls.Generator

  import Ecto.Query

  @stamina_cost 20
  @stamina_threshold 30
  @default_turns 2

  @doc """
  Checks whether two NPCs have enough stamina to converse.
  """
  def can_converse?(npc_a_id, npc_b_id) do
    stamina_a = get_stamina(npc_a_id)
    stamina_b = get_stamina(npc_b_id)
    stamina_a >= @stamina_threshold and stamina_b >= @stamina_threshold
  end

  @doc """
  Runs a multi-turn autonomous conversation between two NPCs.

  Returns `{:ok, scene_id}` so the caller can reference or broadcast the log.
  Returns `{:error, reason}` if either NPC lacks stamina or generation fails.
  """
  @spec run(binary(), binary(), pos_integer()) :: {:ok, binary()} | {:error, term()}
  def run(npc_a_id, npc_b_id, turns \\ @default_turns) do
    npc_a = Characters.get_character!(npc_a_id)
    npc_b = Characters.get_character!(npc_b_id)

    unless can_converse?(npc_a_id, npc_b_id) do
      {:error, :insufficient_stamina}
    else
      drain_stamina(npc_a_id, @stamina_cost)
      drain_stamina(npc_b_id, @stamina_cost)

      scene = find_or_create_autonomous_scene(npc_a, npc_b)

      Logger.info(
        "NPCConversation: #{npc_a.name} ↔ #{npc_b.name} | #{turns} turns | scene #{scene.id}"
      )

      result = run_turns(npc_a, npc_b, scene, turns)

      stamp_social_action(npc_a_id)
      stamp_social_action(npc_b_id)

      result
    end
  end

  # --- Turn loop ---

  defp run_turns(npc_a, npc_b, scene, turns) do
    Enum.reduce_while(1..turns, {:ok, scene.id, :continuing}, fn turn, {_, _, _} ->
      case Generator.generate(npc_a.id, scene.id, npc_b.id) do
        {:ok, msg_a} ->
          state_a = get_in(msg_a.metadata || %{}, ["conversation_state"]) || "continuing"

          if state_a == "concluded" do
            Logger.info("NPCConversation: #{npc_a.name} concluded on turn #{turn}")
            {:halt, {:ok, scene.id, :concluded}}
          else
            case Generator.generate(npc_b.id, scene.id, npc_a.id) do
              {:ok, msg_b} ->
                state_b = get_in(msg_b.metadata || %{}, ["conversation_state"]) || "continuing"

                cond do
                  state_b == "concluded" ->
                    Logger.info("NPCConversation: #{npc_b.name} concluded on turn #{turn}")
                    {:halt, {:ok, scene.id, :concluded}}

                  state_a == "winding_down" or state_b == "winding_down" ->
                    Logger.info("NPCConversation: winding down after turn #{turn}")
                    {:halt, {:ok, scene.id, :winding_down}}

                  true ->
                    Logger.debug("NPCConversation: turn #{turn}/#{turns} complete")
                    {:cont, {:ok, scene.id, :continuing}}
                end

              {:error, reason} ->
                Logger.warning("NPCConversation: #{npc_b.name} failed on turn #{turn}: #{inspect(reason)}")
                {:halt, {:ok, scene.id, :error}}
            end
          end

        {:error, reason} ->
          Logger.warning("NPCConversation: #{npc_a.name} failed on turn #{turn}: #{inspect(reason)}")
          {:halt, {:ok, scene.id, :error}}
      end
    end)
    |> then(fn {status, scene_id, _state} -> {status, scene_id} end)
  end

  # --- Scene management ---

  defp find_or_create_autonomous_scene(npc_a, npc_b) do
    existing = find_existing_autonomous_scene(npc_a.id, npc_b.id)

    if existing do
      existing
    else
      create_autonomous_scene(npc_a, npc_b)
    end
  end

  defp find_existing_autonomous_scene(npc_a_id, npc_b_id) do
    Repo.one(
      from s in SovereignSoulEngine.Scenes.Scene,
        join: pa in assoc(s, :participants),
        join: pb in assoc(s, :participants),
        where:
          s.is_autonomous == true and
            s.status == "active" and
            pa.character_id == ^npc_a_id and
            pb.character_id == ^npc_b_id,
        limit: 1
    )
  end

  defp create_autonomous_scene(npc_a, npc_b) do
    {:ok, scene} =
      Scenes.create_scene(%{
        title: "#{npc_a.name} & #{npc_b.name} — Private",
        status: "active",
        location: "Unknown",
        is_autonomous: true,
        started_at: DateTime.utc_now()
      })

    Scenes.add_participant(%{scene_id: scene.id, character_id: npc_a.id, role: "npc"})
    Scenes.add_participant(%{scene_id: scene.id, character_id: npc_b.id, role: "npc"})

    scene
  end

  # --- Stamina helpers ---

  defp get_stamina(character_id) do
    profile = Souls.get_soul_profile_by_character(character_id)
    (profile && profile.social_stamina) || 80
  end

  defp drain_stamina(character_id, amount) do
    profile = Souls.get_soul_profile_by_character(character_id)

    if profile do
      new_stamina = max((profile.social_stamina || 80) - amount, 0)
      Souls.update_soul_profile(profile, %{social_stamina: new_stamina})
    end
  end

  defp stamp_social_action(character_id) do
    profile = Souls.get_soul_profile_by_character(character_id)
    if profile, do: Souls.update_soul_profile(profile, %{last_social_action_at: DateTime.utc_now()})
  end
end
