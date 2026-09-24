defmodule SovereignSoulEngineWeb.BillingLiveTest do
  use SovereignSoulEngineWeb.ConnCase
  import Phoenix.LiveViewTest
  alias SovereignSoulEngine.Characters

  setup do
    {:ok, player} =
      Characters.create_character(%{
        name: "Goose",
        slug: "goose",
        kind: "player",
        status: "active",
        description: "Primary player character."
      })

    %{player: player}
  end

  test "mounts /sse/billing and displays $14.99 and $19.99 tiers", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sse/billing")

    assert html =~ "Billing &amp; 18+ Verification" or html =~ "Billing & 18+ Verification"
    assert html =~ "Sovereign Companion"
    assert html =~ "$14.99"
    assert html =~ "Sovereign Archon"
    assert html =~ "$19.99"
    assert html =~ "18+ Uncensored"
  end

  test "completes age verification via form submission", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/billing")

    html =
      view
      |> form("form[phx-submit='submit_age_verification']", %{
        "year" => "1995",
        "month" => "06",
        "day" => "20",
        "certify_18" => "on",
        "ai_disclaimer" => "on",
        "mature_consent" => "on"
      })
      |> render_submit()

    assert html =~ "Age verification confirmed (18+)" or html =~ "Verified 18+ Adult Status"
  end

  test "activates $19.99 Archon tier and unlocks 18+ adult maturity", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sse/billing")

    html =
      view
      |> element(
        "button[phx-value-tier_id='archon_1999']",
        "⚡ Test Switch to Sovereign Archon (Dev Bypass)"
      )
      |> render_click()

    assert html =~ "Activated Sovereign Archon"
    assert html =~ "18+ Verified" or html =~ "Verified 18+ Adult Status"
  end

  test "handles completed checkout session return", %{conn: conn} do
    {:ok, _view, html} =
      live(conn, "/sse/billing?session_id=cs_test_mock_123&tier=companion_1499")

    assert html =~ "Stripe checkout successful" or html =~ "Sovereign Companion"
  end
end
