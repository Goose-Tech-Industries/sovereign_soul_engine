defmodule SovereignSoulEngineWeb.ChatTrialAndCreationTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Accounts
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Souls

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "user_#{System.unique_integer([:positive])}@example.com",
        password: "ValidPassword123!",
        opt_out_living_world: false
      })

    player = Characters.get_or_create_player_for_user(user)

    {:ok, companion} =
      Characters.create_living_soul(
        %{
          name: "Aria",
          slug: "aria-#{System.unique_integer([:positive])}",
          kind: "npc",
          status: "active",
          description: "A gentle philosopher",
          user_id: user.id,
          in_living_world: false
        },
        %{
          identity_summary: "A gentle philosopher",
          speech_style: "Poetic and calm"
        }
      )

    scene = Scenes.find_or_create_direct_scene(player, companion)

    conn = log_in_user(Phoenix.ConnTest.build_conn(), user)

    [user: user, player: player, companion: companion, scene: scene, conn: conn]
  end

  describe "Free Trial Message Meter" do
    test "displays free trial count and updates when messages are sent", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/sse/chat")

      assert html =~ "Free Trial"
      assert html =~ "15/15 msgs"

      # Send a message
      render_submit(element(view, "#chat-form"), %{message: %{content: "Hello Aria!"}})

      updated_html = render(view)
      assert updated_html =~ "14/15 msgs"
    end

    test "exhausting 15 trial messages triggers upgrade modal and blocks message sending", %{
      conn: conn,
      player: player,
      scene: scene
    } do
      # Simulate 15 messages already sent by this player
      for i <- 1..15 do
        {:ok, _} =
          Scenes.create_message(%{
            scene_id: scene.id,
            character_id: player.id,
            content: "Message number #{i}",
            message_type: "dialogue"
          })
      end

      {:ok, view, html} = live(conn, ~p"/sse/chat")

      # Should indicate 0/15 msgs and trial exhausted
      assert html =~ "0/15 msgs"
      assert html =~ "Free trial limit reached (15/15 messages)"
      assert html =~ "⚡ Upgrade Now"

      # Attempting to send message 16 should trigger upgrade modal and not send message
      render_submit(element(view, "#chat-form"), %{message: %{content: "Another message past limit"}})

      updated_html = render(view)
      assert updated_html =~ "You have reached your 15 free trial messages"
      assert updated_html =~ "Unlock Sovereign Soul Engine"
      assert updated_html =~ "Companion Unlimited"
      assert updated_html =~ "$14.99"
    end

    test "paid subscription user has unlimited messages", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_user_subscription(user, %{subscription_tier: "companion_1499"})

      {:ok, _view, html} = live(conn, ~p"/sse/chat")

      assert html =~ "companion 1499"
      assert html =~ "Unlimited"
      refute html =~ "15/15 msgs"
    end
  end

  describe "Companion Creation Wizard" do
    test "can open and close companion creation modal", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/sse/chat")

      refute html =~ "Create AI Companion Soul"

      # Open modal
      view |> element("#open-create-soul-btn") |> render_click()
      assert render(view) =~ "Create AI Companion Soul"

      # Close modal
      view |> element("#close-create-companion-modal-btn") |> render_click()
      refute render(view) =~ "Create AI Companion Soul"
    end

    test "creates custom companion in Private Sanctuary mode with greeting", %{
      conn: conn,
      user: user
    } do
      {:ok, view, _html} = live(conn, ~p"/sse/chat")

      # Open modal
      view |> element("#open-create-soul-btn") |> render_click()

      # Submit creation form with Private Sanctuary (in_living_world: false)
      render_submit(element(view, "form[phx-submit='create_custom_companion']"), %{
        "companion" => %{
          "name" => "Seraphina",
          "archetype" => "Empathetic Confidant",
          "avatar_url" => "https://example.com/avatar.jpg",
          "description" => "A warm artist who finds poetry in moonlight.",
          "greeting" => "Welcome. I've been waiting for you.",
          "in_living_world" => "false"
        }
      })

      updated_html = render(view)
      assert updated_html =~ "Created Seraphina!"
      assert updated_html =~ "Seraphina is safe in your Private Sanctuary"
      assert updated_html =~ "Welcome. I&#39;ve been waiting for you."

      # Verify database record
      seraphina = Characters.list_companions_for_user(user.id) |> Enum.find(&(&1.name == "Seraphina"))
      assert seraphina != nil
      assert seraphina.user_id == user.id
      assert seraphina.in_living_world == false
      assert seraphina.metadata["archetype"] == "Empathetic Confidant"

      # Soul profile was created
      profile = Souls.get_soul_profile_by_character(seraphina.id)
      assert profile != nil
      assert profile.identity_summary =~ "warm artist"
    end
  end
end
