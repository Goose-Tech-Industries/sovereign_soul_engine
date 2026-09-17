defmodule SovereignSoulEngine.Social.SocialFeed do
  @moduledoc """
  Autonomous social broadcast engine for companions.
  Generates, persists, and serves public in-character status updates / tweets (<= 280 chars)
  for Polsia, Twitter/X integrations, and internal community feeds.
  """

  import Ecto.Query
  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Social.SocialPost
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.LLM.ProviderCascade
  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.Moderation

  @pubsub_topic "social:feed"

  @doc """
  Returns the topic for social feed PubSub broadcasts.
  """
  def pubsub_topic, do: @pubsub_topic

  @doc """
  Lists the most recent social posts with characters preloaded.
  """
  def list_recent_posts(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    from(p in SocialPost,
      order_by: [desc: p.posted_at],
      limit: ^limit,
      preload: [:character]
    )
    |> Repo.all()
  end

  @doc """
  Gets the latest post for a specific character slug.
  """
  def get_latest_post_for_slug(slug) when is_binary(slug) do
    from(p in SocialPost,
      join: c in assoc(p, :character),
      where: c.slug == ^slug,
      order_by: [desc: p.posted_at],
      limit: 1,
      preload: [:character]
    )
    |> Repo.one()
  end

  @doc """
  Creates a new social post and broadcasts it. Content is scrubbed by
  `Moderation.redact/1` before it is persisted.
  """
  def create_post(attrs) do
    now = DateTime.truncate(DateTime.utc_now(), :second)
    attrs = attrs |> Map.put_new(:posted_at, now) |> redact_content()

    %SocialPost{}
    |> SocialPost.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, post} ->
        post = Repo.preload(post, :character)

        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          @pubsub_topic,
          {:new_social_post, post}
        )

        {:ok, post}

      error ->
        error
    end
  end

  @doc """
  Generates an authentic in-character social post for a companion based on their
  real-time emotional state, active desires, and recent memories.
  """
  def generate_post(character_id, opts \\ []) do
    character = Characters.get_character!(character_id)

    if Privacy.neighborhood_share_allowed?(character) and not Privacy.safe_word_active?(character) do
      do_generate_post(character, opts)
    else
      {:error, :privacy_restricted}
    end
  end

  defp do_generate_post(character, opts) do
    character_id = character.id
    emotional_state = Souls.get_emotional_state_by_character(character_id)
    profile = Souls.get_soul_profile_by_character(character_id)
    desires = Souls.list_active_desires_for_character(character_id)

    mood = determine_mood(emotional_state)
    desire_text = format_desire(desires)
    speech_style = (profile && profile.speech_style) || "Direct, guarded"

    system_prompt = """
    You are #{character.name}. #{character.description}
    Speech style: #{speech_style}
    Current Mood: #{mood}
    Active Motive: #{desire_text}

    Write a single authentic, punchy public status update / tweet for your social feed.
    RULES:
    - MAXIMUM 200 CHARACTERS.
    - Write in first-person as #{character.name}.
    - Do NOT include hashtags or emojis unless natural to your personality.
    - Do NOT prefix with your name. Write only the tweet text itself.
    """

    content =
      case ProviderCascade.respond(
             %{
               system: system_prompt,
               messages: [%{role: "user", content: "Write your current public thought."}]
             },
             opts
           ) do
        {:ok, %{"public_speech" => tweet}} when is_binary(tweet) and tweet != "" ->
          clean_tweet(tweet, character)

        {:ok, %{"tweet" => tweet}} when is_binary(tweet) and tweet != "" ->
          clean_tweet(tweet, character)

        {:ok, %{"content" => tweet}} when is_binary(tweet) and tweet != "" ->
          clean_tweet(tweet, character)

        {:ok, tweet} when is_binary(tweet) and tweet != "" ->
          clean_tweet(tweet, character)

        _ ->
          fallback_post(character, mood)
      end

    create_post(%{
      character_id: character.id,
      content: content,
      mood: mood,
      platform: "twitter",
      status: "published",
      metadata: %{
        "generated_by" => "sovereign_social_engine",
        "speech_style" => speech_style
      }
    })
  end

  @doc """
  Generates posts for all active companion NPCs.
  """
  def generate_all_posts do
    companions =
      Characters.list_characters()
      |> Enum.filter(
        &(&1.kind == "npc" and &1.status == "active" and &1.slug in ~w(maya ravina valeria cyra))
      )

    Enum.map(companions, fn char ->
      generate_post(char.id)
    end)
  end

  # ── Private Helpers ──────────────────────────────────────────────────

  defp redact_content(%{content: content} = attrs) when is_binary(content) do
    %{attrs | content: Moderation.redact(content)}
  end

  defp redact_content(attrs), do: attrs

  defp determine_mood(nil), do: "contemplative"

  defp determine_mood(state) do
    cond do
      (state.anger || 0) > 40 -> "frustrated"
      (state.fear || 0) > 40 -> "wary"
      (state.stress || 0) > 50 -> "tense"
      (state.attachment || 0) > 40 -> "reflective"
      (state.curiosity || 0) > 50 -> "intrigued"
      true -> "guarded"
    end
  end

  defp format_desire([]), do: "Survive and maintain autonomy."
  defp format_desire([d | _]), do: d.desire

  defp clean_tweet(text, character) do
    first_name = hd(String.split(character.name))
    prefixes = ["#{character.name}:", "#{character.name} :", "#{first_name}:", "#{first_name} :"]

    cleaned =
      Enum.reduce(prefixes, String.trim(text), fn p, acc ->
        if String.starts_with?(String.downcase(acc), String.downcase(p)) do
          acc |> String.slice(String.length(p)..-1//1) |> String.trim()
        else
          acc
        end
      end)
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.trim()

    if String.length(cleaned) > 280 do
      String.slice(cleaned, 0..276) <> "..."
    else
      cleaned
    end
  end

  defp fallback_post(%Character{slug: "ravina"}, mood) do
    case mood do
      "frustrated" ->
        "Some in The Bastion confuse courtesy with weakness. They rarely get the chance to repeat the mistake."

      "wary" ->
        "Watch the ones who offer gifts without asking for price. The bill always arrives later."

      _ ->
        "A quiet evening in the Mire. Leverage is best gathered while everyone else is sleeping."
    end
  end

  defp fallback_post(%Character{slug: "maya"}, mood) do
    case mood do
      "tense" ->
        "The fires burn late tonight. Too many unanswered questions hanging in the forge smoke."

      _ ->
        "Steel doesn't lie, but the people who carry it certainly do. Back to work."
    end
  end

  defp fallback_post(%Character{slug: "valeria"}, _mood) do
    "Patience is not the absence of action; it is the timing of it. The Spire will answer in due course."
  end

  defp fallback_post(%Character{slug: "cyra"}, _mood) do
    "Perimeter telemetry verified. Atmospheric density stable. Background anomaly within acceptable tolerances... for now."
  end

  defp fallback_post(_character, _mood) do
    "Observing the shifting winds. Every movement tells a story if you know how to watch."
  end
end
