defmodule SovereignSoulEngineWeb.Api.StripeWebhookControllerTest do
  use SovereignSoulEngineWeb.ConnCase, async: false

  @webhook_secret "whsec_test_secret_key_1234567890abcdef"

  setup do
    prev_secret = System.get_env("STRIPE_WEBHOOK_SECRET")
    System.put_env("STRIPE_WEBHOOK_SECRET", @webhook_secret)

    on_exit(fn ->
      if prev_secret do
        System.put_env("STRIPE_WEBHOOK_SECRET", prev_secret)
      else
        System.delete_env("STRIPE_WEBHOOK_SECRET")
      end
    end)

    :ok
  end

  defp sign_stripe_payload(payload, secret, timestamp) do
    signed_payload = "#{timestamp}.#{payload}"

    sig =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)

    "t=#{timestamp},v1=#{sig}"
  end

  describe "POST /sse/api/webhooks/stripe" do
    test "processes valid signed webhook with recent timestamp", %{conn: conn} do
      payload =
        Jason.encode!(%{
          "type" => "checkout.session.completed",
          "data" => %{
            "object" => %{
              "id" => "cs_test_valid",
              "metadata" => %{"tier_id" => "companion_1499", "character_id" => "goose"}
            }
          }
        })

      now = System.system_time(:second)
      signature = sign_stripe_payload(payload, @webhook_secret, now)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", signature)
        |> post("/sse/api/webhooks/stripe", payload)

      assert json_response(conn, 200)["received"] == true
      assert json_response(conn, 200)["event"] == "checkout.session.completed"
    end

    test "rejects request missing stripe-signature header", %{conn: conn} do
      payload =
        Jason.encode!(%{"type" => "checkout.session.completed", "data" => %{"object" => %{}}})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/sse/api/webhooks/stripe", payload)

      assert response(conn, 400) =~ "Webhook verification failed"
    end

    test "rejects request with forged signature", %{conn: conn} do
      payload =
        Jason.encode!(%{"type" => "checkout.session.completed", "data" => %{"object" => %{}}})

      now = System.system_time(:second)

      bad_signature =
        "t=#{now},v1=0000000000000000000000000000000000000000000000000000000000000000"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", bad_signature)
        |> post("/sse/api/webhooks/stripe", payload)

      assert response(conn, 400) =~ "Webhook verification failed"
    end

    test "rejects expired timestamp (replay attack prevention)", %{conn: conn} do
      payload =
        Jason.encode!(%{"type" => "checkout.session.completed", "data" => %{"object" => %{}}})

      old_timestamp = System.system_time(:second) - 600
      signature = sign_stripe_payload(payload, @webhook_secret, old_timestamp)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", signature)
        |> post("/sse/api/webhooks/stripe", payload)

      assert response(conn, 400) =~ "timestamp_out_of_tolerance"
    end

    test "fails closed when webhook secret is unconfigured and signature is present", %{
      conn: conn
    } do
      System.delete_env("STRIPE_WEBHOOK_SECRET")

      payload =
        Jason.encode!(%{"type" => "checkout.session.completed", "data" => %{"object" => %{}}})

      now = System.system_time(:second)
      signature = "t=#{now},v1=dummy"

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("stripe-signature", signature)
        |> post("/sse/api/webhooks/stripe", payload)

      assert response(conn, 400) =~ "unconfigured_webhook_secret"
    end
  end
end
