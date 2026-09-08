defmodule SovereignSoulEngineWeb.Api.NpcChatController do
  @moduledoc """
  Lets an external game embed a real, stateful 1:1 conversation with one
  of its NPCs — not a link out to SSE's own chat UI. Each external
  player gets a real SSE Character (kind: "player") on first contact, so
  the conversation goes through the actual Consequence/Memory/Relationship
  engine and genuinely shapes how the NPC feels about that specific
  player, same as the dev-harness chat does for "Goose".

  Never returns private_thought — that's for SSE's own inspector view
  only, not something an external game's player should see.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Relationships, Scenes, Tenants}
  alias SovereignSoulEngine.Souls.{ConsequenceEngine, Generator}

  @speak_intensity 30

  def send_message(conn, %{
        "external_source" => source,
        "external_player_id" => player_id,
        "external_player_name" => player_name,
        "npc_id" => npc_id,
        "message" => message
      }) do
    with {:ok, npc} <- fetch_active_npc(npc_id),
         true <- String.trim(message) != "" || {:error, :empty_message} do
      player = Characters.get_or_create_external_player(source, player_id, player_name)
      scene = Scenes.find_or_create_direct_scene(player, npc)

      {:ok, _player_message} =
        Scenes.create_message(%{
          scene_id: scene.id,
          character_id: player.id,
          content: message,
          message_type: "dialogue"
        })

      ConsequenceEngine.resolve(%{
        character_id: player.id,
        source_character_id: player.id,
        target_character_id: npc.id,
        scene_id: scene.id,
        event_type: :speak,
        event_intensity: @speak_intensity,
        correlation_id: Ecto.UUID.generate()
      })

      case Generator.generate(npc.id, scene.id, player.id, conn.assigns.tenant) do
        {:ok, reply} ->
          Tenants.record_llm_call(conn.assigns.tenant)

          json(conn, %{
            npc_name: npc.name,
            reply: reply.content,
            tell: reply.metadata["physical_tell"],
            audio_url: reply.metadata["audio_url"],
            joined_player: reply.metadata["proposed_action"] == "join_player",
            left_player: reply.metadata["proposed_action"] == "leave_player"
          })

        {:error, reason} ->
          conn
          |> put_status(:bad_gateway)
          |> json(%{error: "npc did not respond", reason: inspect(reason)})
      end
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "npc not found"})

      {:error, :empty_message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "message is empty"})
    end
  end

  def history(conn, %{
        "external_source" => source,
        "external_player_id" => player_id,
        "npc_id" => npc_id
      }) do
    with {:ok, npc} <- fetch_active_npc(npc_id),
         player when not is_nil(player) <- Characters.get_external_player(source, player_id),
         scene when not is_nil(scene) <- Scenes.find_direct_scene(player, npc) do
      messages =
        scene.id
        |> Scenes.list_messages()
        |> Enum.map(fn m ->
          %{
            from: if(m.character_id == npc.id, do: npc.name, else: player.name),
            content: m.content
          }
        end)

      json(conn, %{messages: messages})
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "npc not found"})
      _ -> json(conn, %{messages: []})
    end
  end

  @doc """
  source=player, target=npc — CORRECTED from an initial assumption that
  this should be the npc-held direction (source=npc). Verified against
  real data: `apply_action_side_effects/3` (the only thing that ever
  writes a relationship row for 1:1 external chat — `ConsequenceEngine`
  explicitly skips relationship processing for `event_type: :speak`,
  `consequence_engine.ex:211`) always calls `with_relationship(player.id,
  npc.id, ...)`, i.e. source=player. The reverse direction is never
  populated by anything in the 1:1-chat path, so reading it here would
  silently always return "known: false" — confirmed by a real `join_player`
  test call that correctly wrote a source=player row but a source=npc
  read of it came back empty until this fix.
  """
  def relationship(conn, %{
        "external_source" => source,
        "external_player_id" => player_id,
        "npc_id" => npc_id
      }) do
    with {:ok, npc} <- fetch_active_npc(npc_id),
         player when not is_nil(player) <- Characters.get_external_player(source, player_id) do
      case Relationships.get_relationship(player.id, npc.id) do
        nil ->
          json(conn, %{known: false})

        rel ->
          json(conn, %{
            known: true,
            affinity: rel.affinity,
            trust: rel.trust,
            respect: rel.respect,
            fear: rel.fear,
            anger: rel.anger,
            gratitude: rel.gratitude,
            relationship_type: rel.relationship_type
          })
      end
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "npc not found"})
      _ -> json(conn, %{known: false})
    end
  end

  defp fetch_active_npc(id) do
    with {:ok, _} <- Ecto.UUID.cast(id),
         %{kind: "npc", status: "active"} = npc <- Characters.get_character(id) do
      {:ok, npc}
    else
      _ -> {:error, :not_found}
    end
  end
end
