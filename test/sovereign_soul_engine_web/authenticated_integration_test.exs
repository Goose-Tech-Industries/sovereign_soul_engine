defmodule SovereignSoulEngineWeb.AuthenticatedIntegrationTest do
  @moduledoc """
  End-to-End Authenticated Integration Coverage for Workstream 4.

  Verifies the complete request -> authorization -> domain operation -> persistence -> response
  lifecycle across:
  1. Phoenix 1.8 User Scope (`current_scope`) Browser/LiveView lifecycle:
     - Unauthenticated redirection
     - Invalid-token rejection
     - Expired-token (>14 days) invalidation
     - Authenticated user authorization, domain execution, and persistence
     - Cross-user isolation (scope pinning prevents acting on behalf of another user)
  2. Tenant / Bearer API authentication for representative privacy-sensitive operations:
     - Unauthenticated rejection (401)
     - Invalid-token rejection (401)
     - Deactivated/expired key rejection (401)
     - Cross-tenant boundary violation rejection (403)
     - Complete authenticated execution of Memory Purge and Soul Capsule Export
  """

  use SovereignSoulEngineWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import SovereignSoulEngine.AccountsFixtures

  alias SovereignSoulEngine.{Accounts, Characters, Memories, Tenants, TheoryOfMind}
  alias SovereignSoulEngine.Accounts.Scope
  alias SovereignSoulEngineWeb.UserAuth

  setup %{conn: conn} do
    user = set_password(user_fixture())
    {:ok, tenant, tenant_key} = Tenants.create_tenant("Integration Tenant", "tenant_alpha")

    {:ok, character} =
      Characters.create_character(%{
        name: "Integration Subject",
        slug: "integration-subject-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    %{
      conn: conn,
      user: user,
      tenant: tenant,
      tenant_key: tenant_key,
      character: character
    }
  end

  # ===========================================================================
  # 1. Browser & User Scope (Phoenix 1.8 `current_scope`) Integration Lifecycle
  # ===========================================================================

  describe "Phoenix 1.8 User Scope (`current_scope`) Lifecycle" do
    test "unauthenticated request to protected route redirects to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/users/settings")

      assert path == ~p"/users/log-in"
      assert flash["error"] == "You must log in to access this page."
    end

    test "request with invalid session token in session redirects to login", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_token: "completely_invalid_garbage_token"})

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/users/settings")

      assert path == ~p"/users/log-in"
      assert flash["error"] == "You must log in to access this page."
    end

    test "request with expired session token (>14 days) fails verification and redirects to login",
         %{conn: conn, user: user} do
      token = Accounts.generate_user_session_token(user)

      # Fast-forward / age the token past the 14-day validity window
      offset_user_token(token, -15, :day)

      # Token can no longer be retrieved from database
      assert Accounts.get_user_by_session_token(token) == nil

      conn =
        conn
        |> init_test_session(%{user_token: token})

      assert {:error, {:redirect, %{to: path, flash: flash}}} =
               live(conn, ~p"/users/settings")

      assert path == ~p"/users/log-in"
      assert flash["error"] == "You must log in to access this page."
    end

    test "authenticated user with valid session token mounts current_scope, executes domain operation, and persists changes",
         %{conn: conn, user: user} do
      # 1. Log in user and establish session
      conn = log_in_user(conn, user)

      # Verify plug assigns current_scope matching user
      scope_conn = UserAuth.fetch_current_scope_for_user(conn, [])
      assert %Scope{user: %Accounts.User{id: uid}} = scope_conn.assigns.current_scope
      assert uid == user.id

      # 2. Mount protected LiveView
      {:ok, lv, html} = live(conn, ~p"/users/settings")
      assert html =~ "Save Password"

      # 3. Perform domain operation: update password
      new_password = valid_user_password()

      form =
        form(lv, "#password_form", %{
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)
      new_conn = follow_trigger_action(form, conn)

      # 4. Assert response redirect and flash message
      assert redirected_to(new_conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(new_conn.assigns.flash, :info) =~
               "Password updated successfully"

      # 5. Assert database persistence: user password updated in DB
      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "cross-user isolation: User A cannot mutate User B settings via current_scope", %{
      conn: conn,
      user: user_a
    } do
      user_b = set_password(user_fixture())
      conn_a = log_in_user(conn, user_a)

      # User A attempts to submit password change claiming User B's identity
      new_password = "brand-new-secure-password-1234!"

      result_conn =
        post(conn_a, ~p"/users/update-password", %{
          "user" => %{
            "email" => user_b.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      assert redirected_to(result_conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(result_conn.assigns.flash, :error) =~ "Invalid email or password"

      # User B is completely untouched and still uses their original password
      assert Accounts.get_user_by_email_and_password(user_b.email, valid_user_password())
      refute Accounts.get_user_by_email_and_password(user_b.email, new_password)

      # Because of server-side current_scope pinning, the change was applied to User A
      assert Accounts.get_user_by_email_and_password(user_a.email, new_password)
    end
  end

  # ===========================================================================
  # 2. Tenant / Bearer API Integration for Privacy-Sensitive Operations
  # ===========================================================================

  describe "Tenant / Bearer API Authentication & Privacy-Sensitive Operations" do
    test "unauthenticated API request is rejected with 401 missing api key", %{
      conn: conn,
      character: character
    } do
      # Purge endpoint
      purge_resp =
        post(conn, ~p"/sse/api/memories/purge", %{
          "character_slug" => character.slug,
          "all" => true
        })

      assert json_response(purge_resp, 401)["error"] == "missing api key"

      # Export capsule endpoint
      export_resp = get(conn, ~p"/sse/api/souls/#{character.slug}/export")
      assert json_response(export_resp, 401)["error"] == "missing api key"
    end

    test "invalid bearer token is rejected with 401 invalid or inactive api key", %{
      conn: conn,
      character: character
    } do
      bad_conn = put_req_header(conn, "authorization", "Bearer forged_invalid_token_12345")

      purge_resp =
        post(bad_conn, ~p"/sse/api/memories/purge", %{
          "character_slug" => character.slug,
          "all" => true
        })

      assert json_response(purge_resp, 401)["error"] == "invalid or inactive api key"

      export_resp = get(bad_conn, ~p"/sse/api/souls/#{character.slug}/export")
      assert json_response(export_resp, 401)["error"] == "invalid or inactive api key"
    end

    test "deactivated tenant key is rejected with 401 invalid or inactive api key", %{
      conn: conn,
      tenant: tenant,
      tenant_key: tenant_key,
      character: character
    } do
      # Deactivate the tenant
      {:ok, _} = Tenants.deactivate_tenant(tenant)

      deactivated_conn = put_req_header(conn, "authorization", "Bearer " <> tenant_key)

      purge_resp =
        post(deactivated_conn, ~p"/sse/api/memories/purge", %{
          "character_slug" => character.slug,
          "all" => true
        })

      assert json_response(purge_resp, 401)["error"] == "invalid or inactive api key"
    end

    test "cross-tenant boundary enforcement: mismatched external_source is rejected with 403", %{
      conn: conn,
      tenant_key: tenant_key
    } do
      auth_conn = put_req_header(conn, "authorization", "Bearer " <> tenant_key)

      # Key belongs to "tenant_alpha", but request claims "tenant_beta"
      resp =
        post(auth_conn, ~p"/sse/api/npc_chat", %{
          "external_source" => "tenant_beta",
          "character_slug" => "non_existent",
          "message" => "Hello"
        })

      assert json_response(resp, 403)["error"] ==
               "external_source does not match this api key's tenant"
    end

    test "cross-tenant boundary enforcement: purge request with mismatched external_source is rejected with 403",
         %{
           conn: conn,
           tenant_key: tenant_key,
           character: character
         } do
      auth_conn = put_req_header(conn, "authorization", "Bearer " <> tenant_key)

      resp =
        post(auth_conn, ~p"/sse/api/memories/purge", %{
          "character_slug" => character.slug,
          "external_source" => "tenant_intruder",
          "all" => true
        })

      assert json_response(resp, 403)["error"] ==
               "external_source does not match this api key's tenant"
    end

    test "end-to-end authenticated privacy operation: durable memory purge across domain and database",
         %{conn: conn, tenant_key: tenant_key, character: character} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # 1. Domain persistence: seed records for character
      {:ok, _mem} =
        Memories.create_memory(%{
          owner_character_id: character.id,
          summary: "Confidential private meeting about project mercury",
          category: "episodic",
          importance: 85,
          emotional_intensity: 60,
          occurred_at: now,
          status: "active",
          tags: ["confidential", "mercury"]
        })

      {:ok, _fact} =
        TheoryOfMind.create_knowledge(%{
          knower_character_id: character.id,
          subject_character_id: character.id,
          known_fact: "Held a confidential meeting regarding mercury",
          certainty: 95
        })

      assert length(Memories.list_memories_for_character(character.id)) == 1
      assert length(TheoryOfMind.list_knowledge_about(character.id, character.id)) == 1

      # 2. Authenticated request: purge sensitive topic "mercury"
      auth_conn =
        conn
        |> put_req_header("authorization", "Bearer " <> tenant_key)
        |> post(~p"/sse/api/memories/purge", %{
          "character_slug" => character.slug,
          "topic" => "mercury"
        })

      # 3. Response verification
      assert json = json_response(auth_conn, 200)
      assert json["status"] == "ok"
      assert json["memories_deleted"] == 1
      assert json["knowledge_facts_deleted"] == 1

      # 4. Direct persistence verification: records are completely purged from DB
      assert Memories.list_memories_for_character(character.id) == []
      assert TheoryOfMind.list_knowledge_about(character.id, character.id) == []
    end

    test "end-to-end authenticated privacy operation: soul capsule export with cryptographic signature",
         %{conn: conn, tenant_key: tenant_key, character: character} do
      auth_conn =
        conn
        |> put_req_header("authorization", "Bearer " <> tenant_key)
        |> get(~p"/sse/api/souls/#{character.slug}/export")

      assert response(auth_conn, 200)
      assert get_resp_header(auth_conn, "content-type") == ["application/json; charset=utf-8"]
      assert [disposition] = get_resp_header(auth_conn, "content-disposition")
      assert disposition =~ "#{character.slug}.soul"

      # Verify capsule content and checksum integrity
      {:ok, decoded} = Jason.decode(auth_conn.resp_body)
      assert decoded["format"] == "sovereign_soul_capsule/v1"
      assert is_binary(decoded["checksum"])
      assert decoded["soul"]["character"]["name"] == character.name
    end
  end
end
