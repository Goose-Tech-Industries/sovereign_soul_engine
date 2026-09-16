defmodule SovereignSoulEngineWeb.Api.SoulCapsuleController do
  @moduledoc """
  API controller for exporting and importing portable `.soul` digital capsules.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Souls.SoulCapsule

  @doc """
  GET /sse/api/souls/:slug/export
  GET /api/souls/:slug/export
  """
  def export(conn, %{"slug" => slug}) do
    case Characters.get_character_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{slug}' not found."})

      character ->
        case SoulCapsule.export_capsule(character) do
          {:ok, capsule} ->
            json_content = SoulCapsule.to_json(capsule)

            conn
            |> put_resp_content_type("application/json")
            |> put_resp_header("content-disposition", "attachment; filename=\"#{slug}.soul\"")
            |> send_resp(200, json_content)

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Export failed: #{inspect(reason)}"})
        end
    end
  end

  @doc """
  POST /sse/api/souls/import
  POST /api/souls/import
  """
  def import_soul(conn, params) do
    input =
      case params do
        %{"file" => %Plug.Upload{path: path}} ->
          File.read!(path)

        %{"capsule" => capsule} when is_map(capsule) ->
          capsule

        %{"soul" => _} = map ->
          map

        _ ->
          conn.body_params
      end

    overwrite? = params["overwrite"] in [true, "true", 1, "1"]

    case SoulCapsule.import_capsule(input, overwrite: overwrite?) do
      {:ok, character} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "ok",
          character_id: character.id,
          character_slug: character.slug,
          character_name: character.name,
          message: "Soul capsule successfully reconstituted into reality."
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed importing soul capsule: #{inspect(reason)}"})
    end
  end
end
