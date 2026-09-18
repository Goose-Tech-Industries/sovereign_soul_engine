defmodule SovereignSoulEngineWeb.CharacterLiveSoulbookTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.{Characters, Souls, Social.SocialFeed, Relationships}

  setup do
    {:ok, char} =
      Characters.create_living_soul(
        %{
          name: "Seraphina Vale",
          slug: "seraphina-vale-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active",
          description: "Highland gemcutter and keeper of the sanctuary lanterns."
        },
        %{
          speech_style: "Hushed, lyrical, poetic",
          core_values: ["Sanctuary", "Purity of Craft", "Compassion"],
          fears: ["Sudden discord", "Losing memories"],
          desires: ["Restore the grand lantern", "Protect the sanctuary seekers"]
        }
      )

    [character: char]
  end

  describe "mount and routing" do
    test "mounts successfully by character UUID", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/characters/#{char.id}")

      assert html =~ "Seraphina Vale"
      assert html =~ "Soul Profile"
    end

    test "mounts successfully by character slug via /sse/souls/:id", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Seraphina Vale"
      assert html =~ "Soul Profile"
    end

    test "displays character name in top navigation header and title", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Seraphina Vale"
      assert html =~ "SoulBook Feed"
    end

    test "renders active status and NPC badge", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "NPC"
      assert html =~ "ACTIVE"
    end

    test "renders character description and slug handle", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "@#{String.downcase(char.slug)}"
      assert html =~ "Highland gemcutter"
    end
  end

  describe "cryptographic DID identity display" do
    test "renders DID badge with did:soul prefix", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "DID:"
      assert html =~ "did:soul:"
      assert html =~ "RFC-0002 Ed25519 Cryptographically Sealed"
    end
  end

  describe "soul blueprint and psychological architecture" do
    test "renders speech style and tone", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Hushed, lyrical, poetic"
      assert html =~ "Speech Style &amp; Tone" or html =~ "Speech Style & Tone"
    end

    test "renders core values tags", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Sanctuary"
      assert html =~ "Purity of Craft"
      assert html =~ "Compassion"
    end

    test "renders fears and wounds", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Fears &amp; Wounds" or html =~ "Fears & Wounds"
      assert html =~ "Sudden discord"
      assert html =~ "Losing memories"
    end

    test "renders active motives and desires", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Active Motives"
      assert html =~ "Restore the grand lantern"
      assert html =~ "Protect the sanctuary seekers"
    end

    test "renders Big 5 personality traits dimensions", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Personality Dimensions"
      assert html =~ "openness"
      assert html =~ "conscientiousness"
    end
  end

  describe "live neurochemistry and somatics meters" do
    test "renders emotional state meters", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Emotional State &amp; Neurochemistry" or html =~ "Emotional State & Neurochemistry"
      assert html =~ "Curiosity"
      assert html =~ "Confidence"
      assert html =~ "Attachment"
    end

    test "renders somatic state strip", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Fatigue"
      assert html =~ "Stamina"
      assert html =~ "Hunger"
    end
  end

  describe "SoulBook wall activity and posts" do
    test "shows empty wall message when character has no posts", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "SoulBook Wall Activity"
      assert html =~ "hasn&#39;t published to the wall recently" or html =~ "hasn't published to the wall recently"
    end

    test "renders published posts on the character's wall", %{conn: conn, character: char} do
      {:ok, _post} =
        SocialFeed.create_post(%{
          character_id: char.id,
          content: "Polishing the quartz crystal before nightfall.",
          mood: "calm",
          platform: "soulbook"
        })

      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Polishing the quartz crystal before nightfall."
      assert html =~ "SoulBook Wall Activity"
    end

    test "does not display wall posts belonging to other characters", %{conn: conn, character: char} do
      {:ok, other_char} =
        Characters.create_living_soul(%{
          name: "Other Traveler",
          slug: "other-traveler-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      {:ok, _other_post} =
        SocialFeed.create_post(%{
          character_id: other_char.id,
          content: "Secret message from another quarter.",
          mood: "wary",
          platform: "soulbook"
        })

      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      refute html =~ "Secret message from another quarter."
    end
  end

  describe "town relationships and chat actions" do
    test "renders chat buttons linking to 1-on-1 companion chat", %{conn: conn, character: char} do
      {:ok, view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Start Companion Chat"
      assert html =~ "Chat 1-on-1"
      assert has_element?(view, ~s|a[href*="/sse/chat?character=#{char.slug}"]|)
    end

    test "renders empty relationship state when no vectors exist", %{conn: conn, character: char} do
      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Town Ties &amp; Affinities" or html =~ "Town Ties & Affinities"
      assert html =~ "No relationship vectors recorded yet"
    end

    test "renders peer relationship when affinity exists", %{conn: conn, character: char} do
      {:ok, friend} =
        Characters.create_living_soul(%{
          name: "Lyra Weaver",
          slug: "lyra-weaver-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      {:ok, _rel} =
        Relationships.create_relationship(%{
          source_character_id: char.id,
          target_character_id: friend.id,
          affinity: 75,
          trust: 80,
          relationship_type: "Trusted Confidante"
        })

      {:ok, _view, html} = live(conn, ~p"/sse/souls/#{char.slug}")

      assert html =~ "Lyra Weaver"
      assert html =~ "Trusted Confidante"
      assert html =~ "75"
    end
  end

  describe "real-time LiveView PubSub updates" do
    test "updates wall dynamically when new social post arrives", %{conn: conn, character: char} do
      {:ok, view, html} = live(conn, ~p"/sse/souls/#{char.slug}")
      refute html =~ "Fresh dynamic broadcast from the mountains!"

      {:ok, post} =
        SocialFeed.create_post(%{
          character_id: char.id,
          content: "Fresh dynamic broadcast from the mountains!",
          mood: "excited",
          platform: "soulbook"
        })

      send(view.pid, {:new_social_post, post})
      rendered = render(view)
      assert rendered =~ "Fresh dynamic broadcast from the mountains!"
    end

    test "updates emotional state dynamically via emotion_updated PubSub event", %{
      conn: conn,
      character: char
    } do
      {:ok, view, _html} = live(conn, ~p"/sse/souls/#{char.slug}")

      # Update emotion in DB
      emotional = Souls.get_emotional_state_by_character(char.id)
      {:ok, _updated} = Souls.update_emotional_state(emotional, %{curiosity: 99})

      send(view.pid, {:emotion_updated, %{}})
      rendered = render(view)
      assert rendered =~ "99%"
    end

    test "updates relationships dynamically via relationship_updated PubSub event", %{
      conn: conn,
      character: char
    } do
      {:ok, friend} =
        Characters.create_living_soul(%{
          name: "Dynamic Peer",
          slug: "dynamic-peer-#{Ecto.UUID.generate()}",
          kind: "npc",
          status: "active"
        })

      {:ok, view, _html} = live(conn, ~p"/sse/souls/#{char.slug}")

      {:ok, _rel} =
        Relationships.create_relationship(%{
          source_character_id: char.id,
          target_character_id: friend.id,
          affinity: 92,
          relationship_type: "Blood Brother"
        })

      send(view.pid, {:relationship_updated, %{}})
      rendered = render(view)
      assert rendered =~ "Dynamic Peer"
      assert rendered =~ "92"
    end
  end
end
