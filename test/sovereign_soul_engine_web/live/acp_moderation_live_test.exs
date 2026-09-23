defmodule SovereignSoulEngineWeb.AcpModerationLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  alias SovereignSoulEngine.Moderation

  setup %{conn: conn} do
    unless Process.whereis(Moderation) do
      start_supervised!(Moderation)
    end

    user = SovereignSoulEngine.AccountsFixtures.user_fixture()
    previous = Application.get_env(:sovereign_soul_engine, :admin_user_ids, [])
    Application.put_env(:sovereign_soul_engine, :admin_user_ids, [user.id])
    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :admin_user_ids, previous) end)
    %{conn: log_in_user(conn, user)}
  end

  test "mounts moderation dashboard and displays overview", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/sse/acp/moderation")

    assert html =~ "Content Moderation &amp; Human Oversight"
    assert html =~ "Content Maturity Tier"
    assert html =~ "Blocked Terms &amp; Blacklist"
    assert html =~ "Silenced / Muted Souls"
    assert has_element?(view, "button[phx-click='set_maturity_rating'][phx-value-rating='teen']")

    assert has_element?(
             view,
             "button[phx-click='set_maturity_rating'][phx-value-rating='mature']"
           )

    assert has_element?(view, "button[phx-click='set_maturity_rating'][phx-value-rating='adult']")
  end

  test "updates content maturity tier", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/acp/moderation")

    view
    |> element("button[phx-click='set_maturity_rating'][phx-value-rating='adult']")
    |> render_click()

    assert Moderation.get_maturity_rating() == "adult"

    view
    |> element("button[phx-click='set_maturity_rating'][phx-value-rating='mature']")
    |> render_click()

    assert Moderation.get_maturity_rating() == "mature"
  end

  test "adds and removes banned term", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sse/acp/moderation")

    view
    |> form("form[phx-submit='add_term']", %{"term" => "glitchphrase"})
    |> render_submit()

    assert "glitchphrase" in Moderation.blocked_terms()

    view
    |> element("button[phx-click='remove_term'][phx-value-term='glitchphrase']")
    |> render_click()

    refute "glitchphrase" in Moderation.blocked_terms()
  end

  test "mutes and unmutes soul DID", %{conn: conn} do
    did = "did:soul:zlive_test_did"
    {:ok, view, _html} = live(conn, ~p"/sse/acp/moderation")

    view
    |> form("form[phx-submit='mute_did']", %{"did" => did})
    |> render_submit()

    assert did in Moderation.list_muted_dids()

    view
    |> element("button[phx-click='unmute_did'][phx-value-did='#{did}']")
    |> render_click()

    refute did in Moderation.list_muted_dids()
  end
end
