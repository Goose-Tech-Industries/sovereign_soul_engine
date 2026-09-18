defmodule SovereignSoulEngineWeb.Api.StripeWebhookController do
  @moduledoc """
  Ingests Stripe Webhook events for subscription creations, upgrades, and cancellations.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Billing
  alias SovereignSoulEngine.Billing.StripeService

  def webhook(conn, _params) do
    {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
    sig_header = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()

    case StripeService.parse_webhook(raw_body, sig_header) do
      {:ok, %{"type" => "checkout.session.completed", "data" => %{"object" => session}}} ->
        Billing.handle_checkout_completed(session)
        json(conn, %{received: true, event: "checkout.session.completed"})

      {:ok, %{"type" => "customer.subscription.deleted", "data" => %{"object" => _sub}}} ->
        # Downgrade to free tier
        Billing.set_subscription("goose", "free")
        json(conn, %{received: true, event: "customer.subscription.deleted"})

      {:ok, %{"type" => event_type}} ->
        json(conn, %{received: true, event: event_type})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Webhook verification failed", reason: inspect(reason)})
    end
  end
end
