defmodule SovereignSoulEngineWeb.LegalLiveTest do
  use SovereignSoulEngineWeb.ConnCase

  import Phoenix.LiveViewTest

  test "loads Terms of Service page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/terms")

    assert html =~ "Terms of Service"
    assert html =~ "Age Requirement &amp; Informed Consent (18+)"
    assert html =~ "Subscriptions, Free Trials &amp; Billing"
    assert html =~ "$14.99"
    assert html =~ "$19.99"
  end

  test "loads Privacy Policy page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/privacy")

    assert html =~ "Privacy Policy"
    assert html =~ "Our Privacy Commitment"
    assert html =~ "Private Sanctuary Architecture"
    assert html =~ "User Rights &amp; Memory Purging"
  end
end
