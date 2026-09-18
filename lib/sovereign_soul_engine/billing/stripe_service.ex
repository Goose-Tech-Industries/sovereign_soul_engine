defmodule SovereignSoulEngine.Billing.StripeService do
  @moduledoc """
  Stripe Payment & Subscription Integration.

  Handles:
  - The $14.99/mo Companion tier (unlimited chat, biometrics, hands-free voice, dream loops).
  - The $19.99/mo Archon tier (18+ uncensored cinema, commercial age verification, priority ElevenLabs voice, AI expansions).
  - Live Stripe API checkout sessions via Req (Req-only client; no third-party wrapper overhead).
  - Zero-config development mock mode for instant local testing when STRIPE_SECRET_KEY is absent.
  - Webhook ingestion & subscription lifecycle tracking.
  """

  alias SovereignSoulEngine.Characters.Character

  @stripe_api_base "https://api.stripe.com/v1"

  @tiers [
    %{
      id: "companion_1499",
      name: "Sovereign Companion",
      tagline: "Emotional Presence & Living Biometrics",
      price_usd: 14.99,
      cents: 1499,
      interval: "month",
      badge: "PRO COMPANION",
      badge_class: "badge-primary text-primary-content",
      maturity_rating: "mature",
      features: [
        "Unlimited real-time chat with all 50 living souls",
        "Wearables & Samsung Galaxy Watch live biometric HUD",
        "Hands-Free full-duplex voice intercom",
        "Subconscious REM biological dream loop consolidation",
        "SoulBook social feed & MySpace Top 8 companion wall",
        "Feannag's Rest 13-district walkable town map & encounters",
        "Standard M-Rated mature roleplay & language permitted"
      ]
    },
    %{
      id: "archon_1999",
      name: "Sovereign Archon",
      tagline: "18+ Uncensored Cinema & Adult Intimacy",
      price_usd: 19.99,
      cents: 1999,
      interval: "month",
      badge: "18+ UNCENSORED CINEMA",
      badge_class: "badge-error text-rose-200",
      maturity_rating: "adult",
      features: [
        "Everything included in Sovereign Companion ($14.99)",
        "🔞 Full 18+ Adult Cinema Mode: adult intimacy, profanity, dark fantasy gore",
        "Commercial Age Verification via Stripe credit card safe-harbor",
        "Priority ultra-low latency neural voice generation (ElevenLabs)",
        "Multi-companion autonomous group scenes & living society gossip",
        "AI World Architect: procedural district expansions on Feannag's Rest",
        "Portable .soul capsule export/import & encrypted memory vaults",
        "Exclusive Archon golden badge across feeds and town maps"
      ]
    }
  ]

  @doc "Returns the canonical subscription tiers."
  def list_tiers, do: @tiers

  @doc "Returns a specific tier by id."
  def get_tier(tier_id) do
    Enum.find(@tiers, &(&1.id == to_string(tier_id)))
  end

  @doc "Checks if Stripe is configured with live secret credentials."
  def live_configured? do
    secret = System.get_env("STRIPE_SECRET_KEY")
    is_binary(secret) and String.starts_with?(secret, "sk_")
  end

  @doc "Returns the Stripe publishable key if available."
  def publishable_key do
    System.get_env("STRIPE_PUBLISHABLE_KEY") || "pk_test_sovereign_mock"
  end

  @doc """
  Creates a Stripe Checkout Session for a subscription tier.
  When STRIPE_SECRET_KEY is present, calls the live Stripe API via Req.
  Otherwise, returns an instant local mock checkout session for frictionless testing.
  """
  @spec create_checkout_session(String.t(), Character.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def create_checkout_session(tier_id, character, opts \\ []) do
    case get_tier(tier_id) do
      nil ->
        {:error, :invalid_tier}

      tier ->
        base_url = Keyword.get(opts, :base_url, "http://localhost:8561")
        success_url = "#{base_url}/sse/billing/success?session_id={CHECKOUT_SESSION_ID}&tier=#{tier.id}"
        cancel_url = "#{base_url}/sse/billing/cancel"

        secret_key = System.get_env("STRIPE_SECRET_KEY")

        if is_binary(secret_key) and String.starts_with?(secret_key, "sk_") do
          call_stripe_checkout(secret_key, tier, character, success_url, cancel_url)
        else
          # Instant development mock session
          mock_session_id = "cs_mock_#{tier.id}_#{System.unique_integer([:positive])}"
          resolved_success_url = String.replace(success_url, "{CHECKOUT_SESSION_ID}", mock_session_id)

          {:ok,
           %{
             id: mock_session_id,
             url: resolved_success_url,
             mode: :mock,
             tier: tier.id,
             amount_cents: tier.cents
           }}
        end
    end
  end

  # Live Stripe API call using Req
  defp call_stripe_checkout(secret_key, tier, character, success_url, cancel_url) do
    form_params = [
      {"mode", "subscription"},
      {"success_url", success_url},
      {"cancel_url", cancel_url},
      {"line_items[0][price_data][currency]", "usd"},
      {"line_items[0][price_data][product_data][name]", tier.name},
      {"line_items[0][price_data][product_data][description]", tier.tagline},
      {"line_items[0][price_data][unit_amount]", to_string(tier.cents)},
      {"line_items[0][price_data][recurring][interval]", tier.interval},
      {"line_items[0][quantity]", "1"},
      {"metadata[tier_id]", tier.id},
      {"metadata[character_id]", character.id},
      {"metadata[character_name]", character.name},
      {"metadata[age_verified]", "true"}
    ]

    case Req.post("#{@stripe_api_base}/checkout/sessions",
           auth: {:bearer, secret_key},
           form: form_params,
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok,
         %{
           id: body["id"],
           url: body["url"],
           mode: :live,
           tier: tier.id,
           amount_cents: tier.cents
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:stripe_error, status, body}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  @doc "Validates and parses incoming Stripe webhook payload."
  def parse_webhook(payload, signature_header \\ nil) do
    webhook_secret = System.get_env("STRIPE_WEBHOOK_SECRET")

    cond do
      is_binary(webhook_secret) and is_binary(signature_header) ->
        verify_stripe_signature(payload, signature_header, webhook_secret)

      true ->
        # Decode JSON payload directly in development
        case Jason.decode(payload) do
          {:ok, event} -> {:ok, event}
          {:error, err} -> {:error, :json_decode_error, err}
        end
    end
  end

  defp verify_stripe_signature(payload, signature_header, secret) do
    # Simple HMAC verification matching Stripe's t=timestamp,v1=signature scheme
    try do
      parts =
        signature_header
        |> String.split(",")
        |> Enum.map(&String.split(&1, "=", parts: 2))
        |> Enum.map(fn [k, v] -> {String.trim(k), String.trim(v)} end)
        |> Map.new()

      timestamp = Map.get(parts, "t")
      signature = Map.get(parts, "v1")

      signed_payload = "#{timestamp}.#{payload}"
      expected_sig = :crypto.mac(:hmac, :sha256, secret, signed_payload) |> Base.encode16(case: :lower)

      if Plug.Crypto.secure_compare(expected_sig, signature) do
        Jason.decode(payload)
      else
        {:error, :invalid_signature}
      end
    rescue
      _ -> {:error, :signature_verification_failed}
    end
  end
end
