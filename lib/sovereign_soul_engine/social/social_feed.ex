defmodule SovereignSoulEngine.Social.SocialFeed do
  @moduledoc """
  Autonomous social broadcast engine for companions.
  Generates, persists, and serves public in-character status updates / tweets (<= 280 chars),
  threaded inter-soul peer conversations, and reactions for SoulBook, Polsia, and town community feeds.
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
  alias SovereignSoulEngine.World.Control, as: WorldControl

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
  Deletes a social post by struct or ID and broadcasts the deletion.
  """
  def delete_post(post_or_id) do
    post =
      case post_or_id do
        %SocialPost{} = p -> p
        id when is_binary(id) -> Repo.get(SocialPost, id)
        _ -> nil
      end

    if post do
      case Repo.delete(post) do
        {:ok, deleted} ->
          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            @pubsub_topic,
            {:social_post_deleted, deleted.id}
          )

          {:ok, deleted}

        error ->
          error
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Appends a threaded comment to a social post's metadata and broadcasts the update.
  """
  def add_comment(post_id, author, comment_text) do
    clean_text = String.trim(to_string(comment_text || ""))

    if clean_text == "" or clean_text == "..." or String.starts_with?(clean_text, "...") do
      {:error, :invalid_comment}
    else
      post = Repo.get(SocialPost, post_id)

      if post do
        clean_comment = Moderation.redact(clean_text)

        author_name =
          case author do
            %Character{} = c -> c.name
            name when is_binary(name) -> name
            _ -> "Resident"
          end

        author_id =
          case author do
            %Character{} = c -> c.id
            _ -> nil
          end

        author_slug =
          case author do
            %Character{} = c -> c.slug
            _ -> "guest"
          end

        comment_entry = %{
          "id" => Ecto.UUID.generate(),
          "author_name" => author_name,
          "author_slug" => author_slug,
          "author_id" => author_id,
          "content" => clean_comment,
          "inserted_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

        current_meta = post.metadata || %{}
        current_comments = Map.get(current_meta, "comments", [])
        updated_comments = current_comments ++ [comment_entry]
        updated_meta = Map.put(current_meta, "comments", updated_comments)

        case post |> SocialPost.changeset(%{metadata: updated_meta}) |> Repo.update() do
          {:ok, updated_post} ->
            updated_post = Repo.preload(updated_post, :character, force: true)

            Phoenix.PubSub.broadcast(
              SovereignSoulEngine.PubSub,
              @pubsub_topic,
              {:post_updated, updated_post}
            )

            {:ok, updated_post, comment_entry}

          error ->
            error
        end
      else
        {:error, :not_found}
      end
    end
  end

  @doc """
  Increments a reaction counter ("love", "honor", "fire", "laugh", "moon") on a post.
  """
  def react_to_post(post_id, reaction_type)
      when reaction_type in ["love", "honor", "fire", "laugh", "moon"] do
    post = Repo.get(SocialPost, post_id)

    if post do
      current_meta = post.metadata || %{}
      current_reactions = Map.get(current_meta, "reactions", %{})
      count = Map.get(current_reactions, reaction_type, 0) + 1
      updated_reactions = Map.put(current_reactions, reaction_type, count)
      updated_meta = Map.put(current_meta, "reactions", updated_reactions)

      case post |> SocialPost.changeset(%{metadata: updated_meta}) |> Repo.update() do
        {:ok, updated_post} ->
          updated_post = Repo.preload(updated_post, :character, force: true)

          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            @pubsub_topic,
            {:post_updated, updated_post}
          )

          {:ok, updated_post}

        error ->
          error
      end
    else
      {:error, :not_found}
    end
  end

  def react_to_post(_post_id, _invalid_type), do: {:error, :invalid_reaction}

  @doc """
  Lightweight in-character NPC response to a comment on their post.
  Dynamically contextualizes against the character persona and comment content.
  """
  def generate_npc_comment_reply(post_id, npc_id, player_comment) do
    npc = Characters.get_character(npc_id)
    post = Repo.get(SocialPost, post_id)

    if npc && post do
      reply_text = build_in_character_comment_reply(npc, player_comment)

      reply_text =
        if meaningful_speech?(reply_text) do
          reply_text
        else
          build_inter_soul_dialogue(npc, post.character || npc, post.content, [])
        end

      add_comment(post_id, npc, reply_text)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Generates an autonomous inter-soul reply from one NPC responding to another NPC's post.
  Creates natural peer conversation in the public social feed.
  """
  def generate_inter_soul_reply(post_id, replying_npc_id, opts \\ []) do
    replying_npc = Characters.get_character(replying_npc_id)
    post = Repo.get(SocialPost, post_id) |> Repo.preload(:character)

    if replying_npc && post && post.character do
      existing_comments =
        (post.metadata || %{})
        |> Map.get("comments", [])
        |> Enum.map(&Map.get(&1, "content", ""))

      reply_text =
        case generate_llm_inter_soul_reply(replying_npc, post.character, post.content, opts) do
          {:ok, text} when is_binary(text) and text != "" ->
            clean = clean_comment_text(text, replying_npc)

            if valid_comment?(clean, existing_comments) do
              clean
            else
              build_inter_soul_dialogue(
                replying_npc,
                post.character,
                post.content,
                existing_comments
              )
            end

          _ ->
            build_inter_soul_dialogue(
              replying_npc,
              post.character,
              post.content,
              existing_comments
            )
        end

      add_comment(post_id, replying_npc, reply_text)
    else
      {:error, :not_found}
    end
  end

  @doc """
  Triggers 1 to 2 peer companions to organically respond and react to a social post.
  """
  def trigger_inter_soul_response(post, count \\ 1, opts \\ []) do
    post = Repo.preload(post, :character)
    author_id = post.character_id

    active_npcs =
      Characters.list_living_world_characters()
      |> Enum.filter(&(&1.kind == "npc" and &1.status == "active" and &1.id != author_id))

    if active_npcs != [] do
      selected_responders = Enum.take_random(active_npcs, min(count, length(active_npcs)))

      replies =
        Enum.map(selected_responders, fn responder ->
          generate_inter_soul_reply(post.id, responder.id, opts)
        end)

      # Also add an organic reaction from an additional companion
      reaction_candidates =
        Enum.reject(active_npcs, &(&1.id in Enum.map(selected_responders, fn r -> r.id end)))

      if reaction_candidates != [] do
        reaction_type = Enum.random(["honor", "love", "fire", "moon", "laugh"])
        react_to_post(post.id, reaction_type)
      end

      {:ok, post, replies}
    else
      {:error, :no_responders_available}
    end
  end

  @doc """
  Sparks full autonomous community interaction across Feannag's Rest:
  An active soul creates a post, and peer souls engage with replies and reactions.
  """
  def spark_inter_soul_activity(opts \\ []) do
    all_npcs =
      Characters.list_living_world_characters()
      |> Enum.filter(&(&1.kind == "npc" and &1.status == "active"))

    # Prefer characters that have not posted in the last 15 posts to ensure all 50 rotate
    recent_poster_ids =
      list_recent_posts(limit: 15)
      |> Enum.map(& &1.character_id)

    unposted_npcs = Enum.reject(all_npcs, &(&1.id in recent_poster_ids))

    candidate =
      case unposted_npcs do
        [] -> if all_npcs != [], do: Enum.random(all_npcs), else: nil
        candidates -> Enum.random(candidates)
      end

    if candidate do
      case generate_post(candidate.id, opts) do
        {:ok, post} ->
          trigger_inter_soul_response(post, 2, opts)
          {:ok, post}

        error ->
          error
      end
    else
      {:error, :no_active_npcs}
    end
  end

  @doc """
  Generates an authentic in-character social post for a companion based on their
  real-time emotional state, active desires, and recent memories.
  """
  def generate_post(character_id, opts \\ []) do
    character = Characters.get_character!(character_id)

    cond do
      WorldControl.paused?() ->
        {:error, :world_paused}

      not Privacy.neighborhood_share_allowed?(character) or Privacy.safe_word_active?(character) ->
        {:error, :privacy_restricted}

      true ->
        do_generate_post(character, opts)
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

    recent_contents =
      from(p in SocialPost,
        order_by: [desc: p.posted_at, desc: p.inserted_at],
        limit: 50,
        select: p.content
      )
      |> Repo.all()

    content =
      case ProviderCascade.respond(
             %{
               system: system_prompt,
               messages: [%{role: "user", content: "Write your current public thought."}]
             },
             opts
           ) do
        {:ok, %{public_speech: tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, %{"public_speech" => tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, %{tweet: tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, %{"tweet" => tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, %{content: tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, %{"content" => tweet}} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        {:ok, tweet} when is_binary(tweet) and tweet != "" ->
          process_generated_tweet(tweet, character, mood, recent_contents)

        _ ->
          fallback_post(character, mood, recent_contents)
      end

    create_post(%{
      character_id: character.id,
      content: content,
      mood: mood,
      platform: "soulbook",
      status: "published",
      metadata: %{
        "generated_by" => "sovereign_social_engine",
        "speech_style" => speech_style,
        "location" => (profile && profile.identity_summary) || "Feannag's Rest",
        "comments" => [],
        "reactions" => %{"love" => 1, "honor" => 1, "fire" => 0, "laugh" => 0, "moon" => 1}
      }
    })
  end

  @doc """
  Generates posts for all active companion NPCs across the town.
  """
  def generate_all_posts do
    companions =
      Characters.list_living_world_characters()
      |> Enum.filter(&(&1.kind == "npc" and &1.status == "active"))

    Enum.map(companions, fn char ->
      generate_post(char.id)
    end)
  end

  # ── Dynamic In-Character Reply Builder ───────────────────────────────

  defp build_in_character_comment_reply(npc, comment) do
    text = String.downcase(to_string(comment || ""))

    case npc.slug do
      "fia" ->
        cond do
          String.contains?(text, "fear") or String.contains?(text, "scared") or
              String.contains?(text, "shadow") ->
            "Do not let the shadow take root. The heart's resonance is always stronger when you breathe through it."

          String.contains?(text, "code") or String.contains?(text, "architecture") or
              String.contains?(text, "system") ->
            "Even intricate systems carry the spirit of the one who shaped them. The foundation feels sound."

          true ->
            "I hear the sincerity in your voice. Every word leaves a gentle resonance across the high spires."
        end

      "cipher" ->
        cond do
          String.contains?(text, "safe") or String.contains?(text, "trust") or
              String.contains?(text, "secure") ->
            "Trust requires cryptographic proof. Verify the SHA-256 signatures before lowering perimeter shields."

          true ->
            "Telemetry log registered. Air-gapped thread state updated and indexed."
        end

      "quill" ->
        "Recorded into the Iron Chronicler's marginalia. Every statement here contributes to the living archive."

      "dove" ->
        "May the Morrígan's blessing shield your footsteps. Walk with purpose and an open heart."

      "kael" ->
        "Keep your voice low along the river pier. The Blackwater currents carry whispers further than you think."

      "egon" ->
        "Mind the market laws while you're in King's Plaza, traveler. Keep the peace and we'll get along fine."

      "ravina" ->
        "An intriguing claim. Let us see what that conviction is worth when the account comes due."

      "corvus" ->
        "Acknowledged. Southern garrison perimeter watches remain on double alert."

      "vael" ->
        "Words are easily spent like copper coin. Let your deeds prove what you say."

      "lyra" ->
        "Every thought is another thread woven into the town's pattern. I see how your stitch fits."

      "maya" ->
        "Steel doesn't lie, and neither should you. Keep your hammer steady and your word true."

      "valeria" ->
        "The weave remembers what the Spire foretold. Time will test the mettle of that vow."

      "cyra" ->
        "Atmospheric variance monitored. Biometric telemetry remains within acceptable parameters."

      "bram" ->
        "Pull up a stool by the hearth and have a draught of mead! Words go down better with warm bread."

      "elowen" ->
        "Drink a cup of willow-bark tea and rest. Healing takes patience and quiet soil."

      "tavish" ->
        "Keep your voice low and your coin close, friend. The docks have a way of listening."

      "rowan" ->
        "Good craftsmanship speaks for itself. Keep your foundation level and your timber dry."

      _ ->
        "Your reflection is acknowledged by #{npc.name}. Feannag's Rest remembers every truth spoken in its light."
    end
  end

  # ── Inter-Soul Dialogue Generator ────────────────────────────────────

  defp generate_llm_inter_soul_reply(replying_npc, author, post_content, opts) do
    if Keyword.get(opts, :hermetic, false) or Mix.env() == :test do
      {:error, :hermetic_mode}
    else
      character_id = replying_npc.id
      emotional_state = Souls.get_emotional_state_by_character(character_id)
      profile = Souls.get_soul_profile_by_character(character_id)
      mood = determine_mood(emotional_state)
      speech_style = (profile && profile.speech_style) || "Direct, in-character"

      system_prompt = """
      You are #{replying_npc.name}. #{replying_npc.description}
      Speech style: #{speech_style}
      Current Mood: #{mood}

      You are commenting publicly on a town social feed post written by #{author.name}:
      "#{post_content}"

      RULES:
      - MAXIMUM 120 CHARACTERS.
      - Write a single concise, punchy in-character public comment.
      - React directly to what #{author.name} said from your personal trade, worldview, and personality.
      - Do NOT prefix with your name or '@' handle. Write only the comment itself.
      """

      case ProviderCascade.respond(
             %{
               system: system_prompt,
               messages: [%{role: "user", content: "Write your public comment."}]
             },
             opts
           ) do
        {:ok, %{public_speech: tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, %{"public_speech" => tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, %{content: tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, %{"content" => tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, %{comment: tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, %{"comment" => tweet}} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        {:ok, tweet} when is_binary(tweet) ->
          if meaningful_speech?(tweet), do: {:ok, tweet}, else: {:error, :llm_fallback}

        _ ->
          {:error, :llm_unavailable}
      end
    end
  end

  defp meaningful_speech?(val) when is_binary(val) do
    trimmed = String.trim(val)

    trimmed != "" and trimmed != "..." and
      not String.starts_with?(trimmed, "...") and
      not String.contains?(trimmed, "<|") and
      not String.starts_with?(trimmed, "{\"") and
      byte_size(trimmed) >= 4
  end

  defp meaningful_speech?(_), do: false

  defp valid_comment?(clean, existing_comments) do
    meaningful_speech?(clean) and clean not in existing_comments
  end

  defp clean_comment_text(text, character) do
    raw = clean_tweet(text, character)

    # Extract clean sentence if LLM returned JSON format
    extracted =
      case Regex.run(~r/^{\s*"([^"]+)"/, raw) do
        [_, inner] -> inner
        _ -> raw
      end

    extracted
    |> String.replace(~r/^@\w+\s*/, "")
    |> String.replace(~r/<\|[^|]+\|>/, "")
    |> String.replace(~r/#\w+.*$/, "")
    |> String.replace(~r/\([^)]*internal monologue[^)]*\)/i, "")
    |> String.replace(~r/\s*-\s*(edited to fit|no, I'll keep it simple).*$/i, "")
    |> String.replace("...", "")
    |> String.trim()
  end

  def build_inter_soul_dialogue(responder, author, post_content, existing_comments \\ []) do
    resp_slug = responder.slug
    auth_slug = author.slug

    pair_reply =
      cond do
        # Responses to Fia
        auth_slug == "fia" and resp_slug == "cipher" ->
          "I analyzed the harmonic data you felt, Fia. Node telemetry confirms an anomalous frequency pulse at the south wall."

        auth_slug == "fia" and resp_slug == "dove" ->
          "The Morrígan hears the same longing, sister. The sanctuary fires will burn through the fog tonight."

        auth_slug == "fia" and resp_slug == "ravina" ->
          "Careful with that open heart, Fia. When you broadcast what you feel, someone always calculates its price."

        # Responses to Cipher
        auth_slug == "cipher" and resp_slug == "fia" ->
          "Circuits and hashes are only half the world, Cipher. The living pulse doesn't run on copper."

        auth_slug == "cipher" and resp_slug == "corvus" ->
          "Keep those telemetry sensors focused on the highland gorge, Cipher. Sentry scouts rely on your early pings."

        auth_slug == "cipher" and resp_slug == "quill" ->
          "The Iron Archives have logged your packet checksums. The council will want an explanation for the surge."

        # Responses to Kael (Docks)
        auth_slug == "kael" and resp_slug == "egon" ->
          "Make sure those barge manifests have proper harbormaster seals before they unload at King's Plaza, Kael."

        auth_slug == "kael" and resp_slug == "ravina" ->
          "A wise harbormaster knows which river crates require thorough inspection and which belong to friends."

        # Responses to Quill (Chronicler)
        auth_slug == "quill" and resp_slug == "valeria" ->
          "Ink outlasts parchment, Quill, but destiny often rewrites the margins when stars converge."

        auth_slug == "quill" and resp_slug == "vael" ->
          "Preserve those covenants carefully. The barrows are crowded with the bones of those who broke their word."

        # Responses to Corvus (Bastion)
        auth_slug == "corvus" and resp_slug == "maya" ->
          "If your rampart sentries need their broadswords sharpened before dusk, send them to the forge, Commander."

        auth_slug == "corvus" and resp_slug == "egon" ->
          "King's Plaza night gates are bolted. The market sentinels stand ready to reinforce the perimeter."

        # Responses to Ravina
        auth_slug == "ravina" and resp_slug == "egon" ->
          "Keep your shadow-runners out of the merchant district, Ravina. My sentinels won't look the other way."

        auth_slug == "ravina" and resp_slug == "fia" ->
          "Behind all that calculated leverage, Ravina, I can still sense the soul that remembers how to trust."

        # Responses to Dove
        auth_slug == "dove" and resp_slug == "soren" ->
          "The sanctuary bells echo in the garden. May the mindfulness of the ancients guide all who listen."

        true ->
          nil
      end

    if pair_reply && pair_reply not in existing_comments do
      pair_reply
    else
      topic = detect_post_topic(post_content)
      desc = String.downcase(responder.description || "")
      candidates = get_archetype_comment_candidates(resp_slug, desc, author.name, topic)

      available = Enum.reject(candidates, fn c -> c in existing_comments end)

      case available do
        [_ | _] ->
          idx = :erlang.phash2({post_content, responder.id}, length(available))
          Enum.at(available, idx)

        [] ->
          "#{author.name}'s reflection carries true resonance in the commons today."
      end
    end
  end

  defp detect_post_topic(content) do
    c = String.downcase(content || "")

    cond do
      String.contains?(c, "debt") or String.contains?(c, "stiletto") or
        String.contains?(c, "shadow") or
        String.contains?(c, "coin") or String.contains?(c, "price") or
        String.contains?(c, "leverage") or
        String.contains?(c, "secret") or String.contains?(c, "page") or
          String.contains?(c, "ledger") ->
        :shadow_debt

      String.contains?(c, "steel") or String.contains?(c, "iron") or String.contains?(c, "forge") or
        String.contains?(c, "craft") or String.contains?(c, "hammer") or
          String.contains?(c, "build") ->
        :craft_forge

      String.contains?(c, "watch") or String.contains?(c, "guard") or String.contains?(c, "wall") or
        String.contains?(c, "sentry") or String.contains?(c, "gate") or
        String.contains?(c, "perimeter") or
        String.contains?(c, "threat") or String.contains?(c, "alert") ->
        :defense_vigilance

      String.contains?(c, "sanctuary") or String.contains?(c, "heal") or
        String.contains?(c, "peace") or
        String.contains?(c, "heart") or String.contains?(c, "bless") or
          String.contains?(c, "comfort") ->
        :sanctuary_peace

      String.contains?(c, "river") or String.contains?(c, "tide") or String.contains?(c, "barge") or
        String.contains?(c, "dock") or String.contains?(c, "water") or
          String.contains?(c, "cargo") ->
        :river_docks

      String.contains?(c, "star") or String.contains?(c, "sky") or String.contains?(c, "spire") or
        String.contains?(c, "prophecy") or String.contains?(c, "moon") or
          String.contains?(c, "dream") ->
        :celestial_mystery

      true ->
        :general
    end
  end

  defp get_archetype_comment_candidates(resp_slug, desc, author_name, topic) do
    cond do
      # Smuggler (Tavish)
      resp_slug == "tavish" or String.contains?(desc, "smuggler") ->
        case topic do
          :shadow_debt ->
            [
              "Keep your voice down along the docks, #{author_name}. Debts like that are best settled in uncounted coin.",
              "A silver stiletto is flashy, #{author_name}, but a quiet crate slipped through a culvert leaves no trail.",
              "Discretion pays better than silver in this town. Just make sure your ledger doesn't list my name."
            ]

          :river_docks ->
            [
              "Watch the Blackwater waterlines tonight, #{author_name}. Some cargo is best unloaded under a dark moon.",
              "Harbor bells don't ring for every barge that docks in the shadows.",
              "The river current is fast tonight. Keep your eyes on the drainage watergate."
            ]

          _ ->
            [
              "Keep your ears open and your purse tucked, #{author_name}.",
              "The morning mist is thick down by the docks today—good weather for keeping a low profile.",
              "Sounds like profitable business, #{author_name}. Rare thing around here."
            ]
        end

      # Woodworker / Carpenter (Rowan)
      resp_slug == "rowan" or String.contains?(desc, "woodworker") or
          String.contains?(desc, "carpenter") ->
        case topic do
          :shadow_debt ->
            [
              "Even seasoned mountain oak splits under that kind of tension, #{author_name}. Tread easy.",
              "A sharp blade cuts clean, #{author_name}, but a fractured beam brings down the whole roof.",
              "Put too much pressure on a dry joint and it snaps. Some debts cost more to collect than they're worth."
            ]

          :craft_forge ->
            [
              "Timber and iron hold the world up, #{author_name}. Honest joinery doesn't lie.",
              "Seasoned ash bends in the mountain squall without splintering. Keep your foundation true."
            ]

          _ ->
            [
              "Good joinery holds forever, #{author_name}. Same goes for a trusted neighbor.",
              "Seasoned ash bends in the storm without snapping. Keep your balance out there.",
              "Framing new roof trusses by the rivermill today. Sturdy timber outlasts fine talk."
            ]
        end

      # Blacksmith (Maya)
      resp_slug == "maya" or String.contains?(desc, "blacksmith") or
          String.contains?(desc, "forge") ->
        case topic do
          :shadow_debt ->
            [
              "Cold steel doesn't haggle, #{author_name}. If you're sharpening knives, mind your fingers.",
              "A stiletto is brittle work. Honest iron forged on the anvil will protect you better than debts."
            ]

          _ ->
            [
              "Solid truth, #{author_name}. Words fade, but sturdy craft endures through any mountain gale.",
              "Keep the bellows pumping. Cold hearths build nothing worth having, #{author_name}.",
              "Steel remembers the hammer. Face the heat and you'll come out tempered."
            ]
        end

      # Innkeeper / Brewer (Bram, Malcolm, etc.)
      resp_slug == "bram" or String.contains?(desc, "innkeeper") or
          String.contains?(desc, "brewer") ->
        case topic do
          :shadow_debt ->
            [
              "Leave the stilettos at the door, #{author_name}! A pint of dark malt stout settles disputes faster.",
              "A full tankard beats a silver stiletto any day of the week, #{author_name}!"
            ]

          _ ->
            [
              "Hear, hear! Drop by the Boar's Tusk later, #{author_name}, the hearth is stoked and the draughts are poured!",
              "Words go down better with a bowl of venison stew and warm barley bread, #{author_name}!",
              "Raise a toast to that! The taproom is lively tonight—plenty of room by the fire."
            ]
        end

      # Watchman / Sentry / Guard (Corvus, Orin, etc.)
      resp_slug in ~w(corvus orin) or String.contains?(desc, "guard") or
        String.contains?(desc, "sentry") or String.contains?(desc, "watchman") or
        String.contains?(desc, "scout") or String.contains?(desc, "bastion") ->
        case topic do
          :shadow_debt ->
            [
              "Keep those debts and stilettos out of the southern ward, #{author_name}. The watch will confiscate both on sight.",
              "The night watch is listening, #{author_name}. Don't let your shadow-games spill onto the ramparts."
            ]

          _ ->
            [
              "The watch hears you, #{author_name}. Boundary patrols will keep an eye on that sector.",
              "The ramparts stand firm tonight. Southern garrison sentries remain on double alert.",
              "Keep the peace in the commons, #{author_name}. Sentry bells ring for the safety of all."
            ]
        end

      # Scribe / Chronicler (Quill, etc.)
      resp_slug == "quill" or String.contains?(desc, "scribe") or
        String.contains?(desc, "chronicler") or String.contains?(desc, "archivist") ->
        case topic do
          :shadow_debt ->
            [
              "The ink in the Iron Archives never fades, #{author_name}. Every turned page is recorded.",
              "Careful with open ledgers. The council archives have a way of remembering what others forget."
            ]

          _ ->
            [
              "Noted in the district annals, #{author_name}. Every word spoken openly in the commons becomes history.",
              "The parchment preserves what memory lets slip. Your observation has been indexed.",
              "Indelible ink outlasts all spoken disputes. The archives reflect this day's turning."
            ]
        end

      # Spymaster / Shadow Broker (Ravina, etc.)
      resp_slug == "ravina" or String.contains?(desc, "spymaster") or
          String.contains?(desc, "shadow broker") ->
        [
          "A bold thing to post in broad daylight, #{author_name}. Let us see who takes notice.",
          "Every claim is an investment, #{author_name}. Be sure you can afford the return.",
          "Curious how quickly eyes dart to the floor when that truth is spoken aloud."
        ]

      # Candlemaker (Nadia)
      resp_slug == "nadia" or String.contains?(desc, "candlemaker") ->
        case topic do
          :shadow_debt ->
            [
              "Even the sharpest blade casts a long shadow by candlelight, #{author_name}.",
              "Watch you don't burn the ledger while counting your debts in the dark."
            ]

          _ ->
            [
              "A steady wick burns clean through the fiercest gale, #{author_name}.",
              "Rosemary and beeswax bring calm to troubled thoughts. Keep your light steady.",
              "Shadows only exist where there is light to cast them, #{author_name}."
            ]
        end

      # Gravedigger (Yorick)
      resp_slug == "yorick" or String.contains?(desc, "gravedigger") ->
        case topic do
          :shadow_debt ->
            [
              "I've dug cairns for creditors and debtors alike, #{author_name}. In the quiet barrows, all accounts are settled.",
              "Silver stilettos won't buy warmth when the winter frost sets into the stone."
            ]

          _ ->
            [
              "The silent barrows remind us that time smooths away every sharp grievance, #{author_name}.",
              "Respect the silence of the cairns. What is built in humility outlasts all boasting.",
              "The earth treats every soul with equal quiet. Walk gently today."
            ]
        end

      # Stonecarver (Ulric)
      resp_slug == "ulric" or String.contains?(desc, "stonecarver") or
          String.contains?(desc, "mason") ->
        case topic do
          :shadow_debt ->
            [
              "Stilettos break on mountain granite, #{author_name}. Build something solid that outlives your grudges.",
              "Chisel true or step away from the block. Ledgers crumble; stone stands."
            ]

          _ ->
            [
              "Chisel steady and strike true, #{author_name}. Granite doesn't forgive hasty swings.",
              "Gargoyles on the battlements have watched three centuries of talk fade into wind.",
              "Durable craft demands patience. Measure twice before you carve."
            ]
        end

      # Astrologer / Oracle (Valeria, Vesper)
      resp_slug in ~w(valeria vesper) or String.contains?(desc, "astrologer") or
          String.contains?(desc, "oracle") ->
        case topic do
          :shadow_debt ->
            [
              "The celestial ascendant aligns with reckonings this fortnight, #{author_name}. Tread with foresight.",
              "Silver tarnishes under the highland ley lines. The stars warned of this convergence."
            ]

          _ ->
            [
              "The convergence of stars mirrors what you sense below, #{author_name}.",
              "The weave of the Spire shifts with every true thought. Time will reveal the pattern.",
              "Highland ley lines pulse with quiet clarity tonight. Keep your gaze upward."
            ]
        end

      # Apothecary / Herbalist (Elowen, Galen)
      resp_slug in ~w(elowen galen) or String.contains?(desc, "apothecary") or
        String.contains?(desc, "herbalist") or String.contains?(desc, "alchemist") ->
        case topic do
          :shadow_debt ->
            [
              "Stiletto wounds are messy to stitch, #{author_name}. Better to seek calm before blood is drawn.",
              "Bitterness is a slow poison. Make sure you compound the antidote before opening old wounds."
            ]

          _ ->
            [
              "Drink a cup of willow-bark tea and take heart, #{author_name}. Healing takes patience and good soil.",
              "Wise words, #{author_name}. Take care of yourself—I have a fresh kettle of restorative draughts ready if needed.",
              "The herbs on the lower crags grow stronger after the frost. So do we."
            ]
        end

      # Miner (Thorne)
      resp_slug == "thorne" or String.contains?(desc, "miner") ->
        case topic do
          :shadow_debt ->
            [
              "Dig deep enough into debts and all you find is slag and dark stone, #{author_name}.",
              "Rock yields to honest picks, not silver stilettos. Put your muscle into something real."
            ]

          _ ->
            [
              "Deep in the drift, the mountain teaches you what really holds up. Solid rock doesn't boast.",
              "Keep your lantern trimmed and your pick sharp, #{author_name}. Dark tunnels demand respect.",
              "Iron veins run deep under the high ridges. Hard work always surfaces in the end."
            ]
        end

      # Potter (Una)
      resp_slug == "una" or String.contains?(desc, "potter") ->
        case topic do
          :shadow_debt ->
            [
              "Clay under pressure takes form or cracks wide open, #{author_name}. Mind your footing.",
              "River clay remembers the hands that formed it, just like debts remember their makers."
            ]

          _ ->
            [
              "Patience shapes the vessel, #{author_name}. Rush the annealing kiln and the whole urn shatters.",
              "River clay is humble, but glazed properly it outlasts carved marble.",
              "Keep the wheel turning smoothly. Even lopsided clay finds its center with gentle hands."
            ]
        end

      # Glassblower (Wren)
      resp_slug == "wren" or String.contains?(desc, "glassblower") ->
        case topic do
          :shadow_debt ->
            [
              "Brittle things shatter the easiest under pressure, #{author_name}. Be careful how hard you lean.",
              "The hotter the furnace, the clearer the glass. Time reveals what debts are made of."
            ]

          _ ->
            [
              "Anneal the glass slowly or the flaws will splinter in the frost, #{author_name}.",
              "Molten silica takes whatever shape the artisan commands, but only if the breath is steady.",
              "Clear glass reveals everything inside. No hiding flaws in the bright kiln light."
            ]
        end

      # Miller (Ansel)
      resp_slug == "ansel" or String.contains?(desc, "miller") ->
        case topic do
          :shadow_debt ->
            [
              "The millrace grinds everything down to fine meal in time, #{author_name}. No ledger escapes the wheel.",
              "Water keeps flowing no matter whose account is overdrawn."
            ]

          _ ->
            [
              "The river turns the wheel day and night, #{author_name}. Steady rhythm feeds the town.",
              "Winter spelt grinds slow, but the loaves come out dense and nourishing.",
              "Mind the millstones and keep your grain dry. Good flour requires honest care."
            ]
        end

      # Weaver (Lyra, etc.)
      resp_slug == "lyra" or String.contains?(desc, "weaver") or String.contains?(desc, "textile") or
          String.contains?(desc, "tapestry") ->
        [
          "Your thought weaves nicely into the rhythm of the town today, #{author_name}.",
          "Every thread in the loom has its tension. Pull too tight and the warp snaps.",
          "Patterns emerge only when you step back from the shuttle, #{author_name}."
        ]

      # Shepherd / Priestess (Dove)
      resp_slug == "dove" or String.contains?(desc, "shepherd") ->
        case topic do
          :shadow_debt ->
            [
              "May the high sanctuary shelter your spirit from such cold calculation, #{author_name}.",
              "The flock stays together through the fog. Don't let cold ledgers isolate your heart."
            ]

          _ ->
            [
              "Blessings upon your work, #{author_name}. May the light on the high crags keep you steady.",
              "Tend your soul with the same care a shepherd gives to the newborn lamb.",
              "The sanctuary fires burn for every soul seeking quiet shelter."
            ]
        end

      # Farmer (Egon)
      resp_slug == "egon" or String.contains?(desc, "farmer") ->
        case topic do
          :shadow_debt ->
            [
              "Weeds choke the furrow if you don't clear them early, #{author_name}. Same goes for debts.",
              "Good soil doesn't care about stilettos. Keep your boots planted in honest earth."
            ]

          _ ->
            [
              "Fair words, #{author_name}. Just make sure things stay orderly when the trade wagons roll in.",
              "You reap what you cultivate in the spring. Tend your soil well.",
              "The crop doesn't hurry for anyone. Patience fills the granaries."
            ]
        end

      # Jeweler (Fia)
      resp_slug == "fia" or String.contains?(desc, "jeweler") ->
        case topic do
          :shadow_debt ->
            [
              "A stiletto cuts deep, #{author_name}, but a soul that refuses to be owned shines brighter than any cut jewel.",
              "A flawless facet catches the light; a fractured one only cuts."
            ]

          _ ->
            [
              "I can feel the truth in what you wrote, #{author_name}. The whole town feels a little lighter hearing it.",
              "Every rough gem hides a brilliant facet if you know how to shape it.",
              "True value isn't bought with coin; it lives in the resonance between honest souls."
            ]
        end

      # Harbormaster (Kael)
      resp_slug == "kael" or String.contains?(desc, "harbormaster") ->
        case topic do
          :shadow_debt ->
            [
              "Keep your ledger dry, #{author_name}. The Blackwater has swallowed deeper secrets than that.",
              "The river tides carry every rumor down to the estuary eventually."
            ]

          _ ->
            [
              "Sounds like the Blackwater tides are turning, #{author_name}. Stay sharp out there.",
              "River fog is thick along the piers today. Watch your footing on the wet timbers.",
              "Barges are tied off for the night. All quiet along the north quay."
            ]
        end

      # Cryptographer / Sentinel (Cipher, Cyra)
      resp_slug in ~w(cipher cyra) or String.contains?(desc, "cryptographer") or
          String.contains?(desc, "telemetry") ->
        [
          "Observed and verified on the local mesh, #{author_name}. The parameters you described match our baseline readings.",
          "Cryptographic checksums verified. Monitor the sector parameters closely, #{author_name}.",
          "Air-gapped telemetry log indexed. Node parameters remain stable."
        ]

      # Hermit / Veteran (Vael)
      resp_slug == "vael" or String.contains?(desc, "hermit") or String.contains?(desc, "veteran") ->
        [
          "Hold to that truth, #{author_name}. Few things remain intact when the mountain storms roll in.",
          "Words are easily spent like copper coin. Let your deeds prove what you say.",
          "The highland crags don't care about town gossip. Keep your spine straight."
        ]

      # Monk (Soren)
      resp_slug == "soren" or String.contains?(desc, "monk") ->
        [
          "The sanctuary bells echo in the garden. May the mindfulness of the ancients guide all who listen, #{author_name}.",
          "When you release the heavy burden, silence becomes your true sanctuary.",
          "Breathe with the mountain wind. Stillness reveals what flurry obscures."
        ]

      # Tanner (Sable)
      resp_slug == "sable" or String.contains?(desc, "tanner") ->
        case topic do
          :shadow_debt ->
            [
              "Boiled bull-hide turns aside a stiletto easily enough, #{author_name}. Don't brag about sharp toys in the tanner's quarter.",
              "Tough leather outlasts fine talk. Keep your guard up."
            ]

          _ ->
            [
              "Toughen your hide, #{author_name}. Soft words make for poor armor when the mountain frost hits.",
              "Cured leather repels sleet and briars alike. Build for durability."
            ]
        end

      # Herald (Percival)
      resp_slug == "percival" or String.contains?(desc, "herald") ->
        [
          "The High Council hears all declarations made openly in King's Plaza, #{author_name}.",
          "Proclamations made in the commons carry the solemn weight of sworn covenant.",
          "Words spoken under the noonday bell resonate far across the valley."
        ]

      # Cobbler (Hollis)
      resp_slug == "hollis" or String.contains?(desc, "cobbler") ->
        [
          "Walking on stony mountain trails takes good hobnailed boots, #{author_name}. Tread carefully.",
          "Good leather soles keep travelers grounded no matter how rough the road.",
          "Step with intent. The cobblestones remember every footfall."
        ]

      # Librarian (Ivy)
      resp_slug == "ivy" or String.contains?(desc, "librarian") ->
        [
          "Ancient astrological scrolls in the Spire vault speak of times like these, #{author_name}.",
          "The archives hold seven centuries of highland records. Your thought joins the collection.",
          "Parchment and ink are quiet keepers of the truth."
        ]

      # Fletcher (Kestrel)
      resp_slug == "kestrel" or String.contains?(desc, "fletcher") or
          String.contains?(desc, "bowyer") ->
        [
          "Balance the yew recurve with care, #{author_name}. An arrow released clean flies true through crosswinds.",
          "High mountain gusts test the truest aim. Keep your focus sharp.",
          "True craft flies straight and hits where it's aimed."
        ]

      # Courier (Lark)
      resp_slug == "lark" or String.contains?(desc, "courier") or
          String.contains?(desc, "messenger") ->
        [
          "News travels fast across the wynds and rooftops, #{author_name}! Keep moving!",
          "Carrying wax-sealed messages across town today. Words carry real weight!",
          "Quick feet and clear eyes keep you ahead of the highland chill."
        ]

      # Stablemaster (Merritt)
      resp_slug == "merritt" or String.contains?(desc, "stablemaster") ->
        [
          "A calm voice calms the team faster than a whip, #{author_name}. Steady hands on the reins.",
          "Mountain steeds know when their rider is troubled. Keep your breath even.",
          "Treat beasts and travelers with patient care and the team never bolts."
        ]

      # Kennelmaster (Nissa)
      resp_slug == "nissa" or String.contains?(desc, "kennelmaster") ->
        [
          "The highland wolfhounds have their ears pricked toward the ridge, #{author_name}. Alert as ever.",
          "A loyal mastiff watches your back better than any shadow. Stay close to the pack.",
          "The hounds know honest scent from deceit. Trust their instinct."
        ]

      # Ferryman (Rhea)
      resp_slug == "rhea" or String.contains?(desc, "ferryman") or
          String.contains?(desc, "ferrywoman") ->
        [
          "Hauling the chain-barge across the gorge takes steady cadence, #{author_name}. Mist or squall, the river crosses.",
          "The river current yields to iron chains and patient muscle. Keep your footing.",
          "Morning mist is clearing over the Blackwater gorge. Smooth crossing today."
        ]

      # Midwife (Winona)
      resp_slug == "winona" or String.contains?(desc, "midwife") ->
        [
          "Life is too precious to spend on bitter grudges, child. Breathe and let the past rest.",
          "Every generation brings new breath and renewed hope to Feannag's Rest, #{author_name}.",
          "Tend to what lives and grows. The rest is just noise in the wind."
        ]

      # Gardener (Xanthe)
      resp_slug == "xanthe" or String.contains?(desc, "gardener") or
          String.contains?(desc, "botanist") ->
        [
          "Frost-roses bloom in the coldest crags, #{author_name}, but they need clean soil to take root.",
          "Even the briars have their purpose in defending the conservatory.",
          "Tending moon-lilies requires quiet patience. Nature never rushes."
        ]

      # Ranger / Scout (Rook)
      resp_slug == "rook" or String.contains?(desc, "ranger") or String.contains?(desc, "scout") ->
        [
          "The outer crags are quiet today, #{author_name}. When the woods go silent, keep your guard up.",
          "Tracked wolf prints along the ravine boundary. Vigilance out in the trees keeps the settlement safe.",
          "Clear vision and a silent tread, #{author_name}. The high ridges miss nothing."
        ]

      # Minstrel (Sera)
      resp_slug == "sera" or String.contains?(desc, "minstrel") or String.contains?(desc, "bard") ->
        [
          "Old highland melodies tell of days like this, #{author_name}. A song carries what words cannot.",
          "Tuning spruce strings to the evening wind. Your reflection feels like an opening verse.",
          "Music brings people together faster than any magistrate decree, #{author_name}."
        ]

      # Alchemist (Lys)
      resp_slug == "lys" or String.contains?(desc, "alchemist") ->
        [
          "Precipitating truth from dross takes patience, #{author_name}. The alembic drip never rushes.",
          "Refining minerals on the low sand bath taught me that genuine change happens slowly.",
          "Small variations in heat yield entirely different essences, #{author_name}. Balance is key."
        ]

      # Cartographer (Tamsin)
      resp_slug == "tamsin" or String.contains?(desc, "cartographer") ->
        [
          "The contours of this valley shift over the centuries, #{author_name}. Roads endure when traveled with purpose.",
          "A steady compass and a clear head keep you on the true path. Well charted.",
          "Every border on the mountain map was drawn by feet willing to step forward first."
        ]

      # Stonemason (Oswin)
      resp_slug == "oswin" or String.contains?(desc, "stonemason") ->
        [
          "Set the ashlar square and plumb, #{author_name}. An honest foundation outlasts three mortal generations.",
          "Granite doesn't rush and neither do master masons. Solid craft speaks for itself.",
          "Mortar and stone distribute the burden evenly. We stand stronger together."
        ]

      # Fisher (Mara)
      resp_slug == "mara" or String.contains?(desc, "fisher") ->
        [
          "The Blackwater tides take what they want and return what you earn, #{author_name}.",
          "Mending river drift nets teaches you patience. Deep currents reward those who know how to wait.",
          "The river knows every secret dropped into its waters. Keep your counsel clean."
        ]

      # Falconer (Hale)
      resp_slug == "hale" or String.contains?(desc, "falconer") ->
        [
          "A hunting tiercel sees things from a thousand feet up that men walking below completely miss, #{author_name}.",
          "Patience on the gauntlet builds trust that commands cannot force.",
          "The mountain thermals are clean and high today. Keen eyes catch the smallest movements."
        ]

      # Physician (Isolde)
      resp_slug == "isolde" or String.contains?(desc, "physician") or
          String.contains?(desc, "doctor") ->
        [
          "Clean bandages and willow bark heal wounds, #{author_name}, but a calm spirit is the true medicine.",
          "A resting pulse and steady breath mend what fear tried to take. Take good care.",
          "Life clings with stubborn dignity when given half a chance. Keep your heart hopeful."
        ]

      # Baker (Bella)
      resp_slug == "bella" or String.contains?(desc, "baker") ->
        [
          "Warm sourdough loaves fresh from the stone hearth bring peace to any weary soul, #{author_name}!",
          "Slow rising dough makes the finest crust. Same goes for good community.",
          "Nothing draws folks together from the towers to the docks quite like fresh hearth bread!"
        ]

      # Brewer (Jasper)
      resp_slug == "jasper" or String.contains?(desc, "brewer") ->
        [
          "A hearty flagon of dark malt stout warms the bones, #{author_name}! Laughter by the taproom hearth cures all.",
          "Cold cellar aging gives clover mead its true backbone. Raise a tankard to honest neighbors!",
          "Drink hearty tonight, #{author_name}! A warm toast chases the bitterest mountain frost away."
        ]

      # Dyer (Briar)
      resp_slug == "briar" or String.contains?(desc, "dyer") ->
        [
          "Steeping madder and walnut hulls brings rich color from humble roots, #{author_name}.",
          "Highland indigos and saffron dyes tell stories across the town fabric.",
          "Color without a good fixative fades in the rain. True conviction endures."
        ]

      # Cartwright (Cedric)
      resp_slug == "cedric" or String.contains?(desc, "cartwright") ->
        [
          "Shrink-fitting iron around seasoned ash axles keeps the trade wagons rolling, #{author_name}.",
          "One weak spoke shatters the whole wheel on the mountain passes. Keep every link sturdy.",
          "Smooth wheels turn long leagues into peaceful travel. Keep your momentum true."
        ]

      # General Diverse Fallback Options (NEVER a single repetitive catchphrase!)
      true ->
        [
          "#{author_name}'s perspective rings clear today. Feannag's Rest takes notice.",
          "Thoughtful reflection, #{author_name}. The commons are livelier for hearing it.",
          "Spoken with conviction, #{author_name}. Let us see what the turning season brings.",
          "Well said, #{author_name}. Truth carries further than shouting across the valley."
        ]
    end
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

  defp process_generated_tweet(raw_tweet, character, mood, recent_contents) do
    cleaned = clean_tweet(raw_tweet, character)

    if cleaned in recent_contents or String.length(cleaned) < 5 do
      fallback_post(character, mood, recent_contents)
    else
      cleaned
    end
  end

  @doc """
  Generates a variety fallback post when LLM output is unavailable or duplicates a recent post.
  Guarantees non-repetition against `recent_contents`.
  """
  def fallback_post(character, mood, recent_contents \\ []) do
    candidates = candidate_fallback_posts(character, mood) |> Enum.uniq()
    unseen = Enum.reject(candidates, fn post -> post in recent_contents end)

    case unseen do
      [_ | _] = available ->
        Enum.random(available)

      [] ->
        base = Enum.random(candidates)

        variations =
          candidate_temporal_variations(base)
          |> Enum.reject(fn post -> post in recent_contents end)

        case variations do
          [first | _] -> first
          [] -> add_unique_temporal_variation(base, recent_contents)
        end
    end
  end

  @doc """
  Returns a diverse pool of authentic, character-tailored thoughts based on persona, archetype, and mood.
  """
  def candidate_fallback_posts(%Character{slug: "fia"}, mood) do
    base = [
      "The living pulse of Feannag's Rest beats through stone and skin alike. Listen closely enough, and no soul is ever truly alone.",
      "Gazing out at the starlit gorge... when you listen to the silence, the heart finds its balance.",
      "A warm hearth and an open chest. The gemcrafting bench is quiet, but my thoughts are racing with anticipation.",
      "Light refracting through mountain crystal shows colors you never noticed until you slow down.",
      "A whisper on the balcony stones... Feannag's Rest breathes in rhythm with those who dare to care."
    ]

    case mood do
      "frustrated" ->
        [
          "The spiritual resonance in the grand hall is discordant today. Too many souls masking grief behind pride.",
          "It is exhausting watching people build fortress walls around their own hearts."
          | base
        ]

      "reflective" ->
        [
          "Every cut facet in a sapphire mirrors the heart that holds it. I can feel the quiet longing in this city tonight.",
          "Underneath all the bustle and armor, we are all searching for somewhere safe to lay our burdens down."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "cipher"}, mood) do
    base = [
      "Local CUDA weights verified, zero egress telemetry, mathematical sovereignty intact. Trust the code, not the promise.",
      "Cryptographic hash verified across all local peers. Not a single byte leaked to central servers.",
      "Monitoring boundary packet flow. When algorithms preserve dignity, autonomy becomes mathematically certain.",
      "Entropy levels nominal across the local mesh. The perimeter holds silently.",
      "Air-gapped compute buffer synced. The math remains inviolable."
    ]

    case mood do
      "tense" ->
        [
          "Telemetry spike on node 7. Packet jitter indicates an untracked external probe. Rerouting through air-gapped relays.",
          "Anomaly detected in routing table 0x4F. Re-verifying SHA-256 signatures across the defensive perimeter."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "quill"}, mood) do
    base = [
      "Every ledger is an act of defiance against forgetting. The Iron Archives do not discard a single syllable.",
      "Parchment preserves the truth when human memory falters. Three historical volumes bound before nightfall.",
      "Cataloging the oral testimonies from the southern border. History is built one quiet voice at a time.",
      "Ink dries fast in the dry mountain cold, but the recorded covenants endure for centuries.",
      "A society that burns its chronicles will soon burn its own children. The archives remain unyielding."
    ]

    case mood do
      "wary" ->
        [
          "Examining clan treaties from the Fifth Convergence. The oaths written in sheepskin outlived the houses that swore them.",
          "Discrepancies in the merchant customs register. Someone is erasing names from the council records."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "dove"}, mood) do
    base = [
      "A quiet mist settles over the highland cairns. Even the restless winds find rest if you breathe with them.",
      "Bells ringing from the mountain cloister. Take three deep breaths and let the burden go.",
      "Feeding the white doves as twilight blankets the stones. Gentleness is not weakness—it is anchored strength.",
      "The sacred springs run clear through the frost. May your spirit find stillness tonight.",
      "No soul is too far gone for peace. The sanctuary candle stays lit for every wanderer."
    ]

    case mood do
      "reflective" ->
        [
          "The Morrígan watches from the high crags. Walk with purpose, traveler; the sanctuary hearth burns for all who seek peace.",
          "In the stillness between prayers, the stones whisper of all who came before and found sanctuary."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "kael"}, mood) do
    base = [
      "The Blackwater tides wait for no man, high lord or beggar alike. Cargo is secured; the docks are quiet until sunrise.",
      "Tightening mooring ropes against the rising current. The river knows every merchant who ever tried to cheat the harbor.",
      "Cold river fog rolling off the docks. Sentry torches reflect like fallen stars in the dark water.",
      "Another barge safely cleared. Good cedar timbers and smoked fish heading up to King's Plaza.",
      "The river wind has teeth tonight. Best keep your lanterns covered down along the wharf."
    ]

    case mood do
      "wary" ->
        [
          "River patrol caught two unregistered skiffs drifting below the watergate. Someone is testing our customs perimeter.",
          "Strange cargo crates marked with broken wax seals down on pier four. My crew is keeping their blades loose."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "egon"}, mood) do
    base = [
      "Good soil, honest sweat, and a sheathed blade. Keep to the market laws and you'll find no trouble in my square.",
      "Checking stall weights and scales before morning bell. Fair trade is the bedrock of a free settlement.",
      "Lanterns swinging over King's Plaza. Order isn't built on fear—it's built on fair dealing and steady hands.",
      "Cleaned the cobblestones after the caravan departed. Orderly town, orderly mind.",
      "The bells of King's Plaza ring true. Keep your word and your business will thrive here."
    ]

    case mood do
      "tense" ->
        [
          "Two merchant guilds were drawing daggers over stall rents in King's Plaza. Kept the peace without bloodshed today.",
          "Greed always brings trouble into the market. Extra sentries posted by the grain depot tonight."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "vael"}, mood) do
    base = [
      "I keep my oaths to the dead. The living are far too quick to trade honor for convenience.",
      "The barrow mist is cold tonight. Respect the ancestors, and the mountains will respect your footsteps.",
      "Carving an ancient lineage marker into grey slate. Time washes away kingdoms, but the stones remember.",
      "Quiet hours among the cairns. The dead do not lie, and they never break their promises."
    ]

    case mood do
      "wary" ->
        [
          "Footprints near the northern barrows that didn't belong to any gravedigger. Watch the shadows between the cairns.",
          "A broken ward stone along the old sepulcher path. Someone was digging where they shouldn't."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "lyra"}, mood) do
    base = [
      "The warp threads hold the tension, but the weft gives the tapestry its soul. Everything in life is balance.",
      "Highland wool takes the indigo dye deeply if the mountain water is pure. Finished three guild banners before dusk.",
      "A loom tells stories that words cannot speak. Thread by thread, the community pattern emerges.",
      "Carding mountain fleece by the fire. Honest craft grounds the spirit when the world spins too fast."
    ]

    case mood do
      "reflective" ->
        [
          "Every stitch in this shroud carries a prayer for the one who will wear it.",
          "When you pull one loose thread too hard, the entire pattern unravels. Gentleness is a craft of its own."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "corvus"}, mood) do
    base = [
      "A guarded wall makes a peaceful town. Keep your weapons oiled and your senses sharp.",
      "Perimeter sweeps completed. Wind is howling off the crags, but our sentinels stand unyielding.",
      "Inspecting the portcullis winches. Weak links in armor get good scouts killed; never neglect the details.",
      "Watchtower beacon stoked with mountain pine. The Bastion stands vigilant while Feannag's Rest sleeps.",
      "Highland wind carries the scent of pine and iron. The south wall is secure."
    ]

    case mood do
      "tense" ->
        [
          "Highland reavers spotted three leagues north of the gorge. Doubling sentry watches on the southern bastion tonight.",
          "Signal fire flared once along the ridge, then went dark. Shields locked at the garrison gate."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "ravina"}, mood) do
    base = [
      "A quiet evening in the Mire. Leverage is best gathered while everyone else is sleeping.",
      "A ledger of debts is sharper than a silver stiletto if you know when to turn the page.",
      "Shadows stretch long across the lower quarter. The smart players don't shout; they whisper.",
      "Information is the only currency that never depreciates. Keep your ears open and your purse shut.",
      "The alleys of Feannag's Rest have many doors that don't appear on any town magistrate map."
    ]

    case mood do
      "frustrated" ->
        [
          "Some in The Bastion confuse courtesy with weakness. They rarely get the chance to repeat the mistake.",
          "Amateurs trying to run cons in my territory. They will learn the hard way how the Mire works."
          | base
        ]

      "wary" ->
        [
          "Watch the ones who offer gifts without asking for price. The bill always arrives later.",
          "New faces lingering around the canal locks. Someone is looking for a prize they won't find."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "maya"}, mood) do
    base = [
      "Steel doesn't lie, but the people who carry it certainly do. Back to work.",
      "Folding damascus billets until the dawn. You can't rush the temper if you want an edge that endures.",
      "Hammer, anvil, hearth. When everything else feels unsteady, the iron remembers its shape.",
      "Quenched three broadswords in mountain spring water. Pure balance, no flaws."
    ]

    case mood do
      "tense" ->
        [
          "The fires burn late tonight. Too many unanswered questions hanging in the forge smoke.",
          "Someone brought in a fractured blade with strange ritual engravings. This wasn't broken in honest combat."
          | base
        ]

      _ ->
        base
    end
  end

  def candidate_fallback_posts(%Character{slug: "valeria"}, _mood) do
    [
      "Patience is not the absence of action; it is the timing of it. The Spire will answer in due course.",
      "The weave of fate bends, but rarely breaks without warning. Pay heed to the signs in the high winds.",
      "Observing celestial alignments through the Spire lens. Convergence approaches faster than the council admits.",
      "Ancient runes carved in the spire stones resonate at twilight. There are truths older than any mortal crown."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "cyra"}, _mood) do
    [
      "Perimeter telemetry verified. Atmospheric density stable. Background anomaly within acceptable tolerances... for now.",
      "Biometric sensor sweep clean. Node latency holding at 1.4 milliseconds across all sectors.",
      "Sub-harmonic acoustic pulses registered beneath the eastern aqueduct. Running diagnostic trace.",
      "Environmental monitoring arrays recalibrated. Zero anomalous radiation across the perimeter."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "bram"}, _mood) do
    [
      "Spiced mead is warm, the hearth is roaring, and the Boar's Tusk has an open bench for every wanderer tonight!",
      "Fresh venison stew bubbling over the iron cauldron! Even grumpy town guards smile after a warm bowl.",
      "Laughter by the fire is the only true cure for a hard mountain winter. Sing up, friends!",
      "Tapping a fresh keg of blackberry cider. The tavern floor is swept and the fiddler is warming up!"
    ]
  end

  def candidate_fallback_posts(%Character{slug: "elowen"}, _mood) do
    [
      "Found winter-lichen growing on the sheltered side of the monolith. A potent remedy for deep mountain cough.",
      "Drying bundles of mountain sage and chamomile along the rafters. The earth provides if you listen to the soil.",
      "Steeping valerian root for the tired souls at the refuge. Peaceful rest is the greatest medicine.",
      "Gathering mountain moss and rowan berries before the frost deepens. Nature never withholds its healing."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "sera"}, _mood) do
    [
      "Tuning the spruce lute as the mountain shadows stretch. A melody carries what ink and stone can never preserve.",
      "Singing the Ballad of the First Hearth by the tavern fireside. The oldest verses still bring a tear to hardened eyes.",
      "The mountain winds whistle through the archways like an ancient pipe organ. Nature knows all the old songs.",
      "A good ballad doesn't give answers; it gives listeners a place to rest their grief."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "lys"}, _mood) do
    [
      "Peat distillates reacting with powdered mica on the water bath. Small variations in heat yield entirely different essences.",
      "The alembic drips in steady cadence. You cannot hurry chemical transmutation any more than a change of heart.",
      "Purifying silver precipitate for the sanctuary lamps. Light burns purest when the metal is free of dross.",
      "Cataloging the sublimation rates of mountain sulfur. True understanding begins in patient observation."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "tamsin"}, _mood) do
    [
      "Mapping the eastern glacial crevices before the winter thaw. The mountain changes its borders while men sleep.",
      "Calibrating the brass sextant against the North Star. A traveler without a true map is only wandering toward trouble.",
      "Surveying the high ridge passes above Crow's Keep. The contours of this valley tell five centuries of quiet survival.",
      "Drafting parchment charts with oak-gall ink. Roads exist because courageous feet were willing to step first."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "oswin"}, _mood) do
    [
      "Dressing grey granite ashlar for the palace foundation. A stone set square and plumb will outlast three mortal dynasties.",
      "Listening to the ring of the chisel against the quarry block. Stone speaks if you have the patience to listen.",
      "Mortar mixed with river silt and lime. Strong arches don't fight the weight of the mountain—they distribute it.",
      "Trimming the keystone for the south watergate. One honest block holds up the security of an entire district."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "mara"}, _mood) do
    [
      "Hauling the drift nets from the midnight waters of the Blackwater. Silver trout running thick beneath the frost.",
      "Mending hemp lines by the pier lantern. The river currents take what they want and give what you earn.",
      "Reading the morning ripples along the weir. Respect the water, and it feeds your family through the leanest winter.",
      "The river knows every secret dropped into its depths. Best keep your counsel clean on these banks."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "hale"}, _mood) do
    [
      "Peregrine tiercel preening on my leather gauntlet. From a thousand feet up, the disputes of men look smaller than field mice.",
      "Checking the jesses and silver bells. A hunting hawk obeys not out of fear, but out of earned covenant.",
      "Scanning the northern ridges through the eyrie mist. The birds sense the storm two hours before the clouds crest the peak.",
      "Releasing the tiercel into the high wind. There is no freedom like clean mountain thermals."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "isolde"}, _mood) do
    [
      "Dressing clean linen bandages with comfrey salve. Healing the body is simple; soothing the fear behind it takes time.",
      "Sterilizing surgical steel in boiling willow bark water. A steady hand and a calm pulse save lives in the dark.",
      "Tending to the frostbitten couriers in the upper infirmary. Warmth and patience mend what cold tried to take.",
      "Listening to the quiet rhythm of a resting pulse. Life clings fiercely when given half a chance."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "rook"}, _mood) do
    [
      "Tracking wolf prints along the outer crags. The pack keeps their distance so long as the boundary fires are tended.",
      "Camouflaged in pine boughs watching the lower ravine. The best scout is the one no one ever knew was there.",
      "Notching trail markers into grey birch trees. Know your retreat before you ever step into the shadowed hollows.",
      "The high woods are quiet tonight. When the crows stop cawing, that is when you listen closest."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "bella"}, _mood) do
    [
      "Kneading sourdough before the third watch bell. The oven hearth is red-hot and the loaves are rising true.",
      "Dusting pine tables with barley flour. A warm crust of bread can turn a stranger into a loyal friend.",
      "Honey oat rolls fresh from the stone hearth. The sweet steam carries all the way down to the market stalls.",
      "Feeding the wild yeast starter that has lived through three generations. Simple routines anchor a community."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "jasper"}, _mood) do
    [
      "Racking dark malt stout into toasted oak casks. Cold cellar aging gives the brew a backbone worthy of highland folk.",
      "Sampling the autumn clover mead. Sweet on the tongue with a warm burn that chases the deep frost away.",
      "Scrubbing mash tuns with mountain spring water. Clean kettles and honest malt make the finest tavern tankards.",
      "Laughter over an open keg is the shortest distance between two wary neighbors. Drink hearty tonight, friends."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "nadia"}, _mood) do
    [
      "Dipping cotton wicks into melted rosemary beeswax. A steady flame brings comfort through the bitterest mountain storm.",
      "Pouring tallow molds for the watchtowers. A reliable light is the first defense against the mountain dark.",
      "Trimming tapers for the evening vigil. Even the smallest candle can pierce a room full of ancient shadows.",
      "The scent of warm honey and bayberry fills the workshop. Crafting light is quiet, holy work."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "percival"}, _mood) do
    [
      "Polishing the brass herald horn before the morning assembly. When the council speaks, every citizen deserves to hear the truth.",
      "Proclaiming the seasonal market charter across King's Plaza. Clear decrees prevent bitter quarrels.",
      "Checking the wax seals on the clan rolls. Words spoken in public assembly carry the weight of an unbroken bond.",
      "The echo of the herald trumpet rings across the stone walls. Feannag's Rest stands proud and sovereign."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "rowan"}, _mood) do
    [
      "Planing seasoned mountain oak for the watermill gate. Wood has its own grain—fight it and it splinters; work with it and it endures.",
      "Chiseling mortise and tenon joints for the guild hall beams. No nails needed when the joinery is true.",
      "The fragrant scent of shaved cedar fills the workshop. Honest craft leaves sawdust on the boots and peace in the mind.",
      "Fitting heavy ash planks to the garrison doors. Strong wood protects those who sleep beneath its arches."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "sable"}, _mood) do
    [
      "Scraping heavy hides on the beam. Tanning is rough, cold work, but a supple leather cloak keeps the frost from the bone.",
      "Rubbing mutton tallow and neatsfoot oil into saddle straps. Good leather endures a lifetime if you treat it right.",
      "Stretching cured buckskin across drying racks. No shortcuts when you want armor that turns a dagger point.",
      "Stacking durable boots and brigandine jerkins for the sentry watch. Practical craft built for hard winters."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "thorne"}, _mood) do
    [
      "Swinging the pick against the black iron vein four levels deep. The mountain only yields its treasures to sweat and grit.",
      "Testing timber shoring in the lower drift. You respect the rock ceiling, or it reminds you who truly rules down here.",
      "Hauling carts of raw anthracite and iron ore to the surface. The dark depths keep their own secrets.",
      "Breathing the crisp surface air after a twelve-hour shift below. The light looks sweeter after working in the stone."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "una"}, _mood) do
    [
      "Centering river clay on the kick wheel. If your hands waver for an instant, the whole vessel wobbles off true.",
      "Glazing earthenware storage jars in cobalt and ash. Practical beauty that will hold grain for decades.",
      "Stoking the wood kiln to cherry-red heat. The fire transforms fragile mud into ringing ceramic stone.",
      "Unloading cooling amphoras from the kiln chamber. Every vessel carries the imprint of the hands that shaped it."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "wren"}, _mood) do
    [
      "Gathering molten cullet on the blowpipe from the glowing glory hole. Glass must be shaped in the breath between fires.",
      "Blowing thin-walled alembics for the alchemists of the Spire. Precision in glass requires stillness inside.",
      "Annealing stained ruby glass sheets in the lehr oven. Cooling too fast shatters the finest work—patience is everything.",
      "Watching light refract through a newly spun glass disc. A clear pane opens up the dark stone dwellings."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "ansel"}, _mood) do
    [
      "Listening to the rhythmic clatter of the millstones grinding highland spelt. River water never tires, and neither does the mill.",
      "Checking the grain hopper for balance. Fine flour feeds the town; coarse grist goes to the workhorses.",
      "Greasing the heavy oak waterwheel gears with tallow. Constant motion requires faithful maintenance.",
      "White dust in the air and the smell of cracked wheat. The river runs cold, but the mill keeps the settlement alive."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "briar"}, _mood) do
    [
      "Boiling madder root and walnut husks in iron vats. The deepest crimson takes three days of slow steeping.",
      "Hanging skeins of wool along the drying fences. The valley wind flutters with saffron, indigo, and forest moss.",
      "Testing mordant salts on linen fabric. Color without a good fixative fades in the first mountain rain.",
      "My hands are stained indigo to the knuckles today. Crafting beauty is messy, rewarding work."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "cedric"}, _mood) do
    [
      "Fitting iron tires to heavy wagon wheels over a circle of open coals. Shrink-fitting iron around seasoned ash never fails.",
      "Carving sturdy oak spokes with the drawknife. One weak spoke shatters the wheel on the mountain pass.",
      "Checking caravan axle spindles before the trade convoy departs. A smooth wheel turns leagues into easy miles.",
      "Tightening wagon tongues and iron linchpins. The trade caravans depend on wheels that don't quit."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "galen"}, _mood) do
    [
      "Compounding soothing poppy tinctures and willow bark extracts. The balance between remedy and poison is measured in grains.",
      "Grinding dried feverfew in the marble mortar. Scholarly knowledge must serve practical human comfort.",
      "Sealing glass vials of dreamless sleep tonic with beeswax. Rest is the cornerstone of all healing.",
      "Consulting ancient botanical texts by lamplight. The remedies of the ancients remain as true as the mountain bedrock."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "hollis"}, _mood) do
    [
      "Stitching thick leather soles with waxed linen cord. A good boot keeps a watchman steady through a six-hour snow vigil.",
      "Hammering iron hobnails into mountain treads. Gripping slippery slate requires sturdy footwear.",
      "Stretching new calfskin over the wooden last. A comfortable fit makes even the steepest incline bearable.",
      "Polishing cured leather boots with beeswax paste. Take care of your boots and they will carry you home."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "ivy"}, _mood) do
    [
      "Dusting ancient illuminated codices in the Spire repository. The wisdom of fallen dynasties waits quietly on these cedar shelves.",
      "Cataloging star charts and forgotten treaties. An orderly archive is a fortress of memory against ignorance.",
      "Repairing calfskin bindings with bone glue and needle. Every manuscript is an unbroken chain to our ancestors.",
      "The quiet rustle of parchment pages is the loudest sound in the hall. Truth does not need to shout."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "kestrel"}, _mood) do
    [
      "Splitting mountain yew staves for longbows. Wood that grows on wind-swept crags has the greatest snap and resilience.",
      "Fletching grey goose feathers onto cedar shafts with birch pitch. An arrow flies as true as the fletcher's eye.",
      "Balancing broadhead points on the spinning balance board. No room for wobble when shooting into crosswinds.",
      "Binding silk whipping to recurve tips. Quiet focus at the bench makes every shot count."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "lark"}, _mood) do
    [
      "Leaping the stone gutters of the High District with a sealed dispatch. Swift feet and sharp eyes keep the news running.",
      "Checking the leather messenger pouch. A courier's honor is delivering the scroll unopened and on time.",
      "Sprinting through the morning mist before the gates open. The town wakes up to the letters we carry.",
      "Resting against the fountain wall catching my breath. No message too small, no mountain trail too steep."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "merritt"}, _mood) do
    [
      "Currying the winter coats of the mountain draft stallions. A gentle brush and quiet words build unbreakable loyalty.",
      "Checking horseshoes and hooves for stone bruises. A sound horse is a traveler's greatest ally.",
      "Filling cedar mangers with sweet mountain clover hay. The stable is calm and the beasts are warm tonight.",
      "Watching young foals find their footing in the paddock. Life renews itself in the simplest moments."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "nissa"}, _mood) do
    [
      "Grooming the grey wolfhounds by the hearth. These hounds would face a mountain bear to protect the settlement.",
      "Training mastiff pups on scent trials along the perimeter. A sharp nose catches what human eyes miss completely.",
      "The pack sleeps in a quiet circle around the kennel fire. Loyalty is earned through respect and fair treatment.",
      "Listening to the hounds give a single low warning bark. They know every footstep that belongs in Feannag's Rest."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "orin"}, _mood) do
    [
      "Calling out the second night watch from the north tower. The lanterns are steady and the frost is thick on the parapets.",
      "Patrolling the dark wynds with a brass bullseye lantern. Quiet vigilance keeps the townsfolk dreaming peacefully.",
      "Checking padlocks on the merchant storehouses. Order is maintained one locked door at a time.",
      "The bells ring four. Night gives way to dawn, and our watch holds unbroken."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "rhea"}, _mood) do
    [
      "Hauling the heavy iron chain across the churning waters of the Blackwater. The river has mood swings, but the ferry holds true.",
      "Guiding the timber raft through thick river mist. Safe passage across the deep water is a sacred duty.",
      "Coiling wet hemp ropes on the docking post. The current pushes hard, but steady arms keep the crossing safe.",
      "Looking out across the dark water at dusk. A river divides lands, but the ferry joins hearts."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "soren"}, _mood) do
    [
      "Tending the stone bell garden in contemplative silence. When the mind is still, the wind teaches everything you need to know.",
      "Sweeping fallen leaves from the sanctuary flagstones. Mindfulness in small acts brings order to the spirit.",
      "Copying sacred sutras with sumi ink. A humble heart is the only vessel that can hold lasting peace.",
      "Striking the bronze temple gong at twilight. The resonant tone clears away confusion across the entire valley."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "tavish"}, _mood) do
    [
      "Slipping through the watergate culverts while the sentries change watch. The best routes aren't marked on any magistrate map.",
      "Checking false bottoms on the cedar cargo crates. Discretion is worth three times its weight in gold coin.",
      "A quiet nod in the tavern corner seals the arrangement. No paperwork, no taxes, no broken promises.",
      "The shadows under Raven Docks are full of honest profit if you know whose palm to grease and whose eyes to avoid."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "ulric"}, _mood) do
    [
      "Chiseling an ancient clan crest into mountain basalt. My hammer will be quiet one day, but these carvings will speak forever.",
      "Roughing out a granite gargoyle for the bastion parapet. Strong stone sentinels guarding our walls against the dark.",
      "Sweeping stone dust from the bench. Sharp chisels and steady blows turn raw rock into timeless legacy.",
      "Tracing the relief lines on an ancient memorial slab. Honor the fallen with stone that defies decay."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "vesper"}, _mood) do
    [
      "Adjusting the bronze astrolabe on the observatory tower. The planets align in patterns recorded three eras ago.",
      "Mapping the transit of the Violet Comet through the northern sky. The heavens write prophecies for those who look up.",
      "Reading celestial coordinates by tallow candlelight. Earthly troubles seem gentle beneath the endless expanse of stars.",
      "The sky is crystal clear tonight over the high crags. The cosmic dance continues without pause."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "winona"}, _mood) do
    [
      "Welcoming a new soul into Feannag's Rest tonight. A baby's first cry is the most powerful music in the realm.",
      "Boiling clean linens and preparing soothing chamomile washes. Every generation brings fresh hope to our town.",
      "Sitting by the expectant mother's bedside offering quiet reassurance. Strength and gentleness are two sides of the same coin.",
      "Three generations I have helped bring into this world. Life endures through every hardship."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "xanthe"}, _mood) do
    [
      "Pruning frost-roses in the palace conservatory. Even in the deepest cold, living roots prepare for the spring.",
      "Turning compost and rich black loam in the raised beds. Good soil gives life to everything that flourishes above.",
      "Harvesting winter squash and hardy cabbages before the frost hardens. Patience with nature always brings abundance.",
      "Watching green shoots push through cold slate soil. Life will always find a way to reach for the light."
    ]
  end

  def candidate_fallback_posts(%Character{slug: "yorick"}, _mood) do
    [
      "Tending the silent cairns under the barrow pines. The departed sleep in dignity, protected by the mountain stone.",
      "Carving a modest slate marker with steady care. Every life that ended here deserves to be remembered with honor.",
      "Resting on the wooden shovel as twilight settles over the barrows. Death is not an enemy, but a peaceful resting place.",
      "Placing fresh mountain heather on the ancient memorial barrows. Respect for the dead keeps our living hearts humble."
    ]
  end

  def candidate_fallback_posts(%Character{} = character, _mood) do
    desc = String.downcase(character.description || "")

    cond do
      String.contains?(desc, "blacksmith") or String.contains?(desc, "forge") or
        String.contains?(desc, "iron") or String.contains?(desc, "steel") ->
        [
          "The bellows are glowing red in the hearth. A good strike on the anvil clears the mind better than any speech.",
          "Iron only yields when the heat is right. Patience at the forge teaches you how to handle life.",
          "Sharpening scythes and chisels for tomorrow's harvest. Good craft endures through any season.",
          "The rhythmic clang of the anvil echoes across the ward. Honest work keeps the town standing."
        ]

      String.contains?(desc, "alchemist") or String.contains?(desc, "elixir") or
        String.contains?(desc, "distill") or String.contains?(desc, "potion") ->
        [
          "The alembic drip is steady tonight. Subtle shifts in temperature yield completely different virtues from the mountain herbs.",
          "Refining mineral precipitates under low blue flame. Knowledge requires exact measurement and quiet reverence.",
          "Glass retorts bubbling on the sand bath. One drops the solution slowly or the essence volatilizes.",
          "Cataloging reagents from the high crags. Every substance in nature holds an untapped virtue."
        ]

      String.contains?(desc, "herbalist") or String.contains?(desc, "botanist") or
        String.contains?(desc, "moss") or String.contains?(desc, "apothecary") ->
        [
          "Gathered wild yarrow along the damp southern slopes. Even the stone crags nurture remedies if you know where to look.",
          "Pressing medicinal blooms between cedar boards. The fragrance of summer carried into the winter months.",
          "Roots dug before first frost retain their deepest vigor. Healing begins with understanding the season.",
          "Steeping herbal infusions in iron caldrons. A calm heart is the first step toward mending the body."
        ]

      String.contains?(desc, "guard") or String.contains?(desc, "sentry") or
        String.contains?(desc, "bastion") or String.contains?(desc, "scout") ->
        [
          "Perimeter watch reports no breaches. Lanterns are lit along the palisade; sleep soundly tonight, citizens.",
          "Pacing the rampart stones under the northern stars. Cold air keeps the eyes wide and the senses sharp.",
          "Checking the crossbow locks and spear tips. Vigilance is the price of peaceful nights in Feannag's Rest.",
          "Relieving the watch at the midnight bell. All gates barred and passwords accounted for."
        ]

      String.contains?(desc, "innkeeper") or String.contains?(desc, "tavern") or
        String.contains?(desc, "hearth") or String.contains?(desc, "cook") ->
        [
          "Logs are crackling in the hearth and the kettle is whistling. Every traveler has a home by the fire here.",
          "Fresh loaves cooling on the kitchen pine tables. Nothing brings people together like warm bread and good stories.",
          "Sweeping the flagstones and filling the tallow lamps. The doors stay unbolted for those caught in the mountain mist.",
          "A good song and a warm bowl of chowder make even the longest journey worthwhile."
        ]

      String.contains?(desc, "minstrel") or String.contains?(desc, "ballad") or
        String.contains?(desc, "song") or String.contains?(desc, "bard") ->
        [
          "Tuning the lute strings under the eaves. Old songs carry memories across the barrows that ink can never hold.",
          "Composing verses about the founders of Feannag's Rest. Melody has a way of outlasting monarchs.",
          "The rhythm of the rain against the tavern shutters sounds like an ancient mountain reel.",
          "Singing softly as the town lantern-lighters make their rounds. Music warms what fire cannot reach."
        ]

      String.contains?(desc, "weaver") or String.contains?(desc, "textile") or
          String.contains?(desc, "tapestry") ->
        [
          "Shuttle glides through the loom. A single broken thread unravels the cloth—keep every strand true.",
          "Spinning wool from the highland herds. The wheel turns, rhythm steady as a calm heartbeat.",
          "Dyeing skeins in mountain elderberry broth. The colors of our town are drawn directly from the soil.",
          "Setting the warp beams for a grand hall tapestry. Each thread is a person; together we form the shield."
        ]

      String.contains?(desc, "mason") or String.contains?(desc, "stone") or
        String.contains?(desc, "chisel") or String.contains?(desc, "builder") ->
        [
          "Dressing granite blocks for the eastern foundation. Stone doesn't rush, and neither do master builders.",
          "Leveling the cornerstone with plumb line and square. If the foundation is true, the roof never sags.",
          "The chisel sings against mountain slate. Carving shelter that will shelter our grandchildren's children.",
          "Mortar mixing with coarse river sand. Sturdy walls are raised with sweat, patience, and honor."
        ]

      String.contains?(desc, "merchant") or String.contains?(desc, "trader") or
        String.contains?(desc, "stall") or String.contains?(desc, "goods") ->
        [
          "Checking the ledger balances before sunset. Honest weights and fair coin build covenants that last.",
          "Unpacking fresh silks and spices brought up from the southern trade passes. A bustling square is a prosperous town.",
          "Securing the shop shutters against the night gale. Tomorrow brings new barter and fresh caravans.",
          "Every customer brings a story from beyond the mountains. The market is the true heart of Feannag's Rest."
        ]

      String.contains?(desc, "smuggler") or String.contains?(desc, "shadow") or
          String.contains?(desc, "culvert") ->
        [
          "The best deals are sealed with a quiet handshake in the shadow of the wharf.",
          "Moving cargo through the lower aqueducts while the watch is changing sentries.",
          "Discretion is worth more than a pouch of minted crowns in this town.",
          "Knowing which doors stay unlocked after dark is the only real wealth."
        ]

      String.contains?(desc, "woodworker") or String.contains?(desc, "carpenter") or
          String.contains?(desc, "timber") ->
        [
          "Planing oak with the grain. Good woodwork stands true through three generations.",
          "Shaping timber rafters for the high district hall. Sound wood keeps out the bitterest frost.",
          "Mortise and tenon joints cut with care. Strong craft needs neither nails nor loud words.",
          "The scent of cedar shavings on the floor clears the mind better than any sermon."
        ]

      true ->
        [
          "A quiet stillness settles over my quarter in Feannag's Rest. Mind on the work, heart at peace with the highland winds.",
          "Watching the evening mist rise from the valley floor. There is dignity in simple, honest days.",
          "Another day well spent among good neighbors. Feannag's Rest continues to grow stronger stone by stone.",
          "Taking a quiet moment to look out toward the high crags. The mountain stands unmoving, whatever the season.",
          "Listening to the evening bells chime across the district. A peaceful heart makes a sturdy home.",
          "Working quietly until lamplight. Every soul has its part to play in keeping our sanctuary alive.",
          "The mountain air is crisp and clear tonight. Thoughts turn to what we are building together.",
          "Sharing a nod with a passing traveler. Community is forged in a thousand small courtesies.",
          "The lanterns flicker steadily along the stone wynds. Our town endures through every changing season.",
          "Quiet contemplation before retiring for the night. Tomorrow brings honest tasks and open skies.",
          "Breathing in the pine-scented wind off the gorge. True freedom is living peacefully among trusted folk.",
          "The barrows in the distance remind us that we are only caretakers of this soil for a little while."
        ]
    end
  end

  @doc """
  Generates atmospheric temporal variations for a base thought.
  """
  def candidate_temporal_variations(base) do
    prefixes = [
      "As dusk settles over the high crags: ",
      "Under the quiet evening stars—",
      "With the morning bell ringing out: ",
      "Watching the valley mist drift by: ",
      "Taking a quiet breath between tasks—",
      "The highland wind carries a familiar feeling: ",
      "Reflecting as the bells toll the hour: ",
      "At midday beneath the mountain sun: ",
      "In the lantern light of the quiet ward: ",
      "Listening to the mountain river below: "
    ]

    Enum.map(prefixes, fn p -> p <> base end)
  end

  def add_temporal_variation(base) do
    prefixes = [
      "As dusk settles over the high crags: ",
      "Under the quiet evening stars—",
      "With the morning bell ringing out: ",
      "Watching the valley mist drift by: ",
      "Taking a quiet breath between tasks—",
      "The highland wind carries a familiar feeling: ",
      "Reflecting as the bells toll the hour: "
    ]

    Enum.random(prefixes) <> base
  end

  defp add_unique_temporal_variation(base, recent_contents) do
    candidate = add_temporal_variation(base)

    if candidate in recent_contents do
      time_marker = Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
      "#{candidate} [#{time_marker}]"
    else
      candidate
    end
  end
end
