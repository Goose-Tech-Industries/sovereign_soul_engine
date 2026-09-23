defmodule SovereignSoulEngineWeb.AcpAccessTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Accounts
  alias SovereignSoulEngine.AccountsFixtures
  alias SovereignSoulEngineWeb.UserAuth

  setup do
    previous = Application.get_env(:sovereign_soul_engine, :admin_user_ids, [])
    Application.put_env(:sovereign_soul_engine, :admin_user_ids, [])
    on_exit(fn -> Application.put_env(:sovereign_soul_engine, :admin_user_ids, previous) end)
  end

  test "anonymous ACP requests require login", %{conn: conn} do
    assert conn |> get("/sse/acp/moderation") |> redirected_to() == "/users/log-in"
  end

  test "ordinary accounts cannot access ACP", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    assert conn |> log_in_user(user) |> get("/sse/acp/moderation") |> response(403)
  end

  test "LiveView connections require a confirmed allowlisted account" do
    user = AccountsFixtures.user_fixture()
    token = Accounts.generate_user_session_token(user)
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    assert {:halt, _} = UserAuth.on_mount(:require_admin, %{}, %{}, socket)
    assert {:halt, _} = UserAuth.on_mount(:require_admin, %{}, %{"user_token" => token}, socket)
    Application.put_env(:sovereign_soul_engine, :admin_user_ids, [user.id])
    assert {:cont, _} = UserAuth.on_mount(:require_admin, %{}, %{"user_token" => token}, socket)
  end
end
