defmodule SovereignSoulEngineWeb.Api.AccessControlTest do
  use SovereignSoulEngineWeb.ConnCase

  alias SovereignSoulEngine.Tenants
  alias SovereignSoulEngineWeb.Plugs.ApiAuth

  test "both API prefixes reject unauthenticated sensitive requests", %{conn: conn} do
    for prefix <- ["/api", "/sse/api"],
        {method, path} <- [
          {:get, "/memories/inspect"},
          {:post, "/memories/purge"},
          {:get, "/privacy/settings"},
          {:post, "/privacy/settings"},
          {:post, "/privacy/safe_word/clear"},
          {:post, "/webhooks/telegram"},
          {:post, "/alexa"}
        ] do
      response = dispatch(conn, @endpoint, method, prefix <> path, %{})
      assert json_response(response, 401)["error"] == "missing api key"
    end

    for prefix <- ["/api", "/sse/api"] do
      response = post(conn, prefix <> "/webhooks/stripe", %{})
      assert json_response(response, 400)["error"] == "Webhook verification failed"
    end
  end

  test "built-in and environment keys do not bypass tenant authentication", %{conn: conn} do
    previous = System.get_env("SOVEREIGN_SOUL_API_KEY")
    System.put_env("SOVEREIGN_SOUL_API_KEY", "unprovisioned-key")

    on_exit(fn ->
      if previous,
        do: System.put_env("SOVEREIGN_SOUL_API_KEY", previous),
        else: System.delete_env("SOVEREIGN_SOUL_API_KEY")
    end)

    for key <- ["twisted_dev_key", "unprovisioned-key"] do
      response =
        conn |> put_req_header("authorization", "Bearer " <> key) |> get("/api/memories/inspect")

      assert json_response(response, 401)
    end
  end

  test "valid tenants authenticate, mismatched sources and inactive keys fail" do
    {:ok, tenant, key} = Tenants.create_tenant("Access test", "access-test")

    request = fn source ->
      Plug.Test.conn(:post, "/", %{"external_source" => source})
      |> put_req_header("authorization", "Bearer " <> key)
      |> ApiAuth.call([])
    end

    assert request.("access-test").assigns.tenant.id == tenant.id
    assert request.("other").status == 403
    {:ok, _} = Tenants.deactivate_tenant(tenant)
    assert request.("access-test").status == 401
  end
end
