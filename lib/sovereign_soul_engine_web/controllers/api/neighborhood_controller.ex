defmodule SovereignSoulEngineWeb.Api.NeighborhoodController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Neighborhood.Board
  alias SovereignSoulEngine.Social.MeshProtocol

  @doc """
  GET /sse/api/neighborhood/posts
  GET /api/neighborhood/posts
  """
  def posts(conn, params) do
    zone = params["zone"]
    category = params["category"]

    limit =
      case Integer.parse(params["limit"] || "25") do
        {int, _} -> int
        _ -> 25
      end

    posts = Board.list_posts(zone: zone, category: category, limit: limit)

    json(conn, %{
      status: "ok",
      zone: zone || "all",
      count: length(posts),
      posts: posts
    })
  end

  @doc """
  POST /sse/api/neighborhood/posts
  POST /api/neighborhood/posts
  """
  def create(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    attrs = %{
      zone: params["zone"],
      category: params["category"] || :vibe_check,
      content: params["content"] || ""
    }

    case Board.create_post(character_slug, attrs) do
      {:ok, post} ->
        json(conn, %{
          status: "ok",
          message: "Neighborhood post shared successfully.",
          post: post
        })

      {:error, :neighborhood_sharing_disabled} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          status: "error",
          message: "Neighborhood sharing is disabled in privacy settings."
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  POST /sse/api/neighborhood/posts/:id/comment
  POST /api/neighborhood/posts/:id/comment
  """
  def comment(conn, %{"id" => post_id} = params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    content = params["content"] || ""

    case Board.add_comment(post_id, character_slug, content) do
      {:ok, post} ->
        json(conn, %{
          status: "ok",
          message: "Comment added to neighborhood post.",
          post: post
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  POST /sse/api/neighborhood/posts/:id/react
  POST /api/neighborhood/posts/:id/react
  """
  def react(conn, %{"id" => post_id} = params) do
    reaction = params["reaction"] || "like"

    case Board.react_to_post(post_id, reaction) do
      {:ok, post} ->
        json(conn, %{
          status: "ok",
          post: post
        })

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  POST /sse/api/neighborhood/generate
  POST /api/neighborhood/generate
  """
  def autonomous_post(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case Board.generate_autonomous_post(character_slug) do
      {:ok, post} ->
        json(conn, %{
          status: "ok",
          message: "Autonomous neighborhood post broadcasted.",
          post: post
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  @doc """
  POST /sse/api/neighborhood/encounter
  POST /api/neighborhood/encounter
  """
  def encounter(conn, params) do
    soul_a = params["soul_a"] || "maya"
    soul_b = params["soul_b"] || "cyra"

    case MeshProtocol.encounter(soul_a, soul_b) do
      {:ok, encounter_data} ->
        json(conn, %{
          status: "ok",
          message: "P2P Soul Society mesh encounter processed.",
          encounter: encounter_data
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
