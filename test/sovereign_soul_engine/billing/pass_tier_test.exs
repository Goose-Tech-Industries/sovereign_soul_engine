defmodule SovereignSoulEngine.Billing.PassTierTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.{Billing, Characters}

  setup do
    {:ok, char} =
      Characters.create_living_soul(%{
        name: "Tier Test Player",
        slug: "tier-test-player-#{Ecto.UUID.generate()}",
        kind: "player",
        status: "active"
      })

    [character: char]
  end

  describe "tier pricing and feature specifications" do
    test "list_tiers returns companion_1499 and archon_1999" do
      tiers = Billing.list_tiers()
      tier_ids = Enum.map(tiers, & &1.id)

      assert "companion_1499" in tier_ids
      assert "archon_1999" in tier_ids
    end

    test "companion_1499 tier is priced at $14.99 with mature rating" do
      tier = Billing.get_tier("companion_1499")

      assert tier != nil
      assert tier.price_usd == 14.99
      assert tier.cents == 1499
      assert tier.interval == "month"
      assert tier.maturity_rating == "mature"
      assert tier.name =~ "Companion"
      assert length(tier.features) >= 5
    end

    test "archon_1999 tier is priced at $19.99 with adult 18+ rating" do
      tier = Billing.get_tier("archon_1999")

      assert tier != nil
      assert tier.price_usd == 19.99
      assert tier.cents == 1999
      assert tier.interval == "month"
      assert tier.maturity_rating == "adult"
      assert tier.name =~ "Archon"
      assert Enum.any?(tier.features, &String.contains?(&1, "18+"))
    end

    test "get_tier returns nil for invalid tier id" do
      assert Billing.get_tier("unlimited_9999") == nil
      assert Billing.get_tier("") == nil
    end
  end

  describe "age verification safe harbor gate" do
    test "approves adult user born in 1995 with valid consent declarations", %{character: char} do
      attestations = %{
        "certify_18" => true,
        "ai_disclaimer" => true,
        "mature_consent" => true
      }

      assert {:ok, payload} = Billing.verify_age_by_dob(char, "1995-05-14", attestations)
      assert payload["verified"] == true
      assert payload["calculated_age"] >= 18
      assert Billing.age_verified?(char) == true
    end

    test "rejects underage user with :underage error", %{character: char} do
      attestations = %{
        "certify_18" => true,
        "ai_disclaimer" => true,
        "mature_consent" => true
      }

      today = Date.utc_today()
      minor_dob = Date.to_iso8601(Date.add(today, -15 * 365))

      assert {:error, :underage, msg} = Billing.verify_age_by_dob(char, minor_dob, attestations)
      assert msg =~ "at least 18 years old"
      assert Billing.age_verified?(char) == false
    end

    test "rejects verification when consent attestations are missing", %{character: char} do
      assert {:error, :missing_consent, msg} =
               Billing.verify_age_by_dob(char, "1990-01-01", %{})

      assert msg =~ "confirm the 18+ certification"
      assert Billing.age_verified?(char) == false
    end

    test "rejects invalid date format strings", %{character: char} do
      assert {:error, :invalid_dob, _reason} =
               Billing.verify_age_by_dob(char, "invalid-date", %{"certify_18" => true})
    end

    test "credit card verification awards commercial safe harbor age verification", %{character: char} do
      assert {:ok, payload} = Billing.verify_age_by_credit_card(char)
      assert payload["verified"] == true
      assert payload["method"] == "credit_card_stripe"
      assert Billing.age_verified?(char) == true
    end

    test "get_age_status returns detailed verification structure", %{character: char} do
      status_before = Billing.get_age_status(char)
      assert status_before.verified? == false

      Billing.verify_age_by_credit_card(char)
      status_after = Billing.get_age_status(char)
      assert status_after.verified? == true
      assert status_after.method == "credit_card_stripe"
    end
  end

  describe "subscription management and tier transitions" do
    test "newly created player defaults to free community tier", %{character: char} do
      sub = Billing.get_subscription(char)

      assert sub.tier_id == "free"
      assert sub.price_usd == 0.0
      assert sub.status == "active"
      assert sub.maturity_rating == "teen"
    end

    test "sets subscription to companion_1499", %{character: char} do
      assert {:ok, sub} = Billing.set_subscription(char, "companion_1499")

      assert sub.tier_id == "companion_1499"
      assert sub.price_usd == 14.99
      assert sub.maturity_rating == "mature"
      assert Billing.get_subscription(char).tier_id == "companion_1499"
    end

    test "setting archon_1999 automatically grants commercial 18+ age verification", %{character: char} do
      assert Billing.age_verified?(char) == false

      assert {:ok, sub} = Billing.set_subscription(char, "archon_1999")

      assert sub.tier_id == "archon_1999"
      assert sub.price_usd == 19.99
      assert sub.maturity_rating == "adult"
      assert sub.age_verified? == true
      assert Billing.age_verified?(char) == true
    end

    test "set_subscription rejects invalid tier IDs", %{character: char} do
      assert {:error, :invalid_tier} = Billing.set_subscription(char, "fake_tier_123")
    end

    test "cancel_subscription reverts status to canceled and downgrades to free", %{character: char} do
      {:ok, sub_active} = Billing.set_subscription(char, "companion_1499")
      assert sub_active.tier_id == "companion_1499"

      assert {:ok, sub_canceled} = Billing.cancel_subscription(char)
      assert sub_canceled.tier_id == "free"
      assert sub_canceled.status == "canceled"
    end

    test "mock checkout session returns local test checkout URL", %{character: char} do
      assert {:ok, session} = Billing.create_checkout_session("companion_1499", char)
      assert is_binary(session.url)
      assert session.url =~ "session_id=cs_mock_" or session.url =~ "stripe.com"
    end
  end
end
