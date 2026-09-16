defmodule SovereignSoulEngineWeb.Api.VisionController do
  @moduledoc """
  Ingests visual camera frames and smart glasses snapshots (Ray-Ban Meta, Mentra Live).
  Dispatches to PerceptionEngine to create episodic visual memories and trigger companion dialogue.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Vision.PerceptionEngine

  @doc """
  POST /sse/api/vision/perceive
  POST /api/vision/perceive
  """
  def perceive(conn, params) do
    companion_slug = params["character_slug"] || params["slug"] || "vael"
    player_slug = params["player_slug"] || "goose"
    source = params["source"] || "smart_glasses"
    generate_reaction? = Map.get(params, "generate_reaction", true)

    companion = Characters.get_character_by_slug(companion_slug)
    player = Characters.get_character_by_slug(player_slug)

    cond do
      is_nil(companion) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Companion character '#{companion_slug}' not found."})

      is_nil(player) ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Player character '#{player_slug}' not found."})

      not SovereignSoulEngine.Privacy.vision_allowed?(player.id) ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Smart glasses vision perception is disabled in user privacy settings."})

      true ->
        image_input = extract_image_input(params)

        {:ok, %{perception: perception, reaction: reaction}} =
          PerceptionEngine.perceive(companion, player, image_input,
            source: source,
            scene_id: params["scene_id"],
            generate_reaction: generate_reaction?
          )

        conn
        |> put_status(:ok)
        |> json(%{
          status: "ok",
          companion_slug: companion.slug,
          player_slug: player.slug,
          perception: %{
            scene_description: perception.scene_description,
            user_affect: perception.user_affect,
            salient_objects: perception.salient_objects,
            lighting: perception.lighting,
            source: perception.source,
            timestamp: perception.timestamp
          },
          reaction:
            if reaction do
              %{
                content: reaction.content,
                private_thought: reaction.private_thought
              }
            else
              nil
            end
        })
    end
  end

  defp extract_image_input(%{"image" => %Plug.Upload{path: temp_path}}) do
    case File.read(temp_path) do
      {:ok, binary} -> Base.encode64(binary)
      _ -> "placeholder_image_data"
    end
  end

  defp extract_image_input(%{"image_base64" => b64}) when is_binary(b64), do: b64
  defp extract_image_input(%{"image_data" => data}) when is_binary(data), do: data
  defp extract_image_input(%{"description" => _} = map), do: map
  defp extract_image_input(_), do: "simulated_smart_glasses_frame"
end
