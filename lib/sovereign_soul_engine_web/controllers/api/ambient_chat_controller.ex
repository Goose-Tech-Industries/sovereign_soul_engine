defmodule SovereignSoulEngineWeb.Api.AmbientChatController do
  @moduledoc """
  Group/ambient chat for an external game — many players and NPCs sharing
  one physical-location scene (e.g. a map tile), unlike NpcChatController's
  1:1 direct conversations. An NPC doesn't reply to every line said near
  them: `message/2` just persists a player's line into the shared scene;
  `npc_reply/2` is called once per NPC present, and only actually invokes
  the LLM if Souls.interested_in_message?/2 says that NPC would plausibly
  notice — a deterministic gate, not a model call, so NPCs default to
  silence instead of spamming every ambient exchange.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.{Characters, Scenes, Tenants}
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.Generator

  def message(conn, %{
        "external_source" => source,
        "external_player_id" => player_id,
        "external_player_name" => player_name,
        "group_key" => group_key,
        "message" => message
      }) do
    if String.trim(message) == "" do
      conn |> put_status(:unprocessable_entity) |> json(%{error: "message is empty"})
    else
      player = Characters.get_or_create_external_player(source, player_id, player_name)
      scene = Scenes.find_or_create_group_scene(source, group_key)

      {:ok, _message} =
        Scenes.create_message(%{scene_id: scene.id, character_id: player.id, content: message, message_type: "dialogue"})

      json(conn, %{scene_id: scene.id, player_id: player.id})
    end
  end

  def npc_reply(conn, %{
        "npc_id" => npc_id,
        "scene_id" => scene_id,
        "player_id" => player_id,
        "message" => message
      }) do
    with {:ok, npc} <- fetch_active_npc(npc_id) do
      if Souls.interested_in_message?(npc, message) do
        case Generator.generate(npc.id, scene_id, player_id, conn.assigns.tenant) do
          {:ok, reply} ->
            Tenants.record_llm_call(conn.assigns.tenant)
            json(conn, %{responded: true, npc_name: npc.name, reply: reply.content})

          {:error, reason} ->
            conn |> put_status(:bad_gateway) |> json(%{error: "npc did not respond", reason: inspect(reason)})
        end
      else
        json(conn, %{responded: false})
      end
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "npc not found"})
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
