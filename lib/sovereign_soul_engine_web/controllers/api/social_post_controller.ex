defmodule SovereignSoulEngineWeb.Api.SocialPostController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Social.SocialFeed
  alias SovereignSoulEngine.Characters

  @doc """
  GET /sse/api/social/feed or GET /api/social/feed
  Returns recent social posts from all companions in JSON format for Polsia / Twitter.
  """
  def index(conn, params) do
    limit =
      case Integer.parse(params["limit"] || "20") do
        {n, _} when n > 0 -> min(n, 100)
        _ -> 20
      end

    posts = SocialFeed.list_recent_posts(limit: limit)

    json(conn, %{
      status: "ok",
      count: length(posts),
      posts: Enum.map(posts, &format_post/1)
    })
  end

  @doc """
  GET /sse/api/social/latest/:slug
  Returns the latest social post from a specific character.
  """
  def latest(conn, %{"slug" => slug}) do
    case SocialFeed.get_latest_post_for_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{status: "error", message: "No posts found for character slug: #{slug}"})

      post ->
        json(conn, %{
          status: "ok",
          post: format_post(post)
        })
    end
  end

  @doc """
  POST /sse/api/social/generate
  Triggers generation of an autonomous in-character post.
  Optional JSON body: `{"slug": "ravina"}`
  """
  def generate(conn, params) do
    slug = params["slug"]

    result =
      if slug && is_binary(slug) do
        case Characters.get_character_by_slug(slug) do
          nil -> {:error, :character_not_found}
          char -> SocialFeed.generate_post(char.id)
        end
      else
        companions =
          Characters.list_characters()
          |> Enum.filter(
            &(&1.kind == "npc" and &1.status == "active" and
                &1.slug in ~w(maya ravina valeria cyra))
          )

        case Enum.random(companions) do
          nil -> {:error, :no_active_companions}
          char -> SocialFeed.generate_post(char.id)
        end
      end

    case result do
      {:ok, post} ->
        conn
        |> put_status(:created)
        |> json(%{
          status: "ok",
          message: "Social post generated successfully",
          post: format_post(post)
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  defp format_post(post) do
    %{
      id: post.id,
      character: (post.character && post.character.name) || "Unknown",
      slug: (post.character && post.character.slug) || "unknown",
      content: post.content,
      mood: post.mood,
      platform: post.platform,
      status: post.status,
      posted_at: post.posted_at,
      metadata: post.metadata
    }
  end
end
