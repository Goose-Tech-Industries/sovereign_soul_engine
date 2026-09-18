defmodule SovereignSoulEngine.BillingTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.Billing
  alias SovereignSoulEngine.Characters

  describe "tiers" do
    test "lists the $14.99 and $19.99 tiers" do
      tiers = Billing.list_tiers()
      ids = Enum.map(tiers, & &1.id)

      assert "companion_1499" in ids
      assert "archon_1999" in ids

      companion = Billing.get_tier("companion_1499")
      assert companion.price_usd == 14.99
      assert companion.cents == 1499

      archon = Billing.get_tier("archon_1999")
      assert archon.price_usd == 19.99
      assert archon.cents == 1999
    end
  end

  describe "age verification" do
    setup do
      player =
        Characters.get_character_by_slug("goose") ||
          elem(
            Characters.create_character(%{
              name: "Goose",
              slug: "goose",
              kind: "player",
              status: "active",
              description: "Primary player character."
            }),
            1
          )

      %{player: player}
    end

    test "rejects birth date for underage user (< 18)", %{player: player} do
      # Underage: born 10 years ago
      underage_date = Date.add(Date.utc_today(), -10 * 365)

      attestations = %{
        "certify_18" => true,
        "ai_disclaimer" => true,
        "mature_consent" => true
      }

      assert {:error, :underage, msg} = Billing.verify_age_by_dob(player, underage_date, attestations)
      assert msg =~ "at least 18 years old"
    end

    test "requires informed consent checkboxes", %{player: player} do
      valid_adult_date = ~D[2000-01-01]

      missing_consent = %{
        "certify_18" => true,
        "ai_disclaimer" => false,
        "mature_consent" => true
      }

      assert {:error, :missing_consent, _msg} = Billing.verify_age_by_dob(player, valid_adult_date, missing_consent)
    end

    test "approves valid 18+ birth date with consent and saves metadata", %{player: player} do
      valid_adult_date = ~D[1998-05-15]

      attestations = %{
        "certify_18" => true,
        "ai_disclaimer" => true,
        "mature_consent" => true
      }

      assert {:ok, verif} = Billing.verify_age_by_dob(player, valid_adult_date, attestations)
      assert verif["verified"] == true
      assert verif["method"] == "dob_attestation"
      assert Billing.age_verified?(player)
    end

    test "awards commercial credit card verification", %{player: player} do
      assert {:ok, verif} = Billing.verify_age_by_credit_card(player, %{session_id: "cs_test_123"})
      assert verif["verified"] == true
      assert verif["method"] == "credit_card_stripe"
      assert Billing.age_verified?(player)
    end
  end

  describe "subscriptions" do
    setup do
      player =
        Characters.get_character_by_slug("goose") ||
          elem(
            Characters.create_character(%{
              name: "Goose",
              slug: "goose",
              kind: "player",
              status: "active",
              description: "Primary player character."
            }),
            1
          )

      %{player: player}
    end

    test "activates $14.99 Companion tier", %{player: player} do
      assert {:ok, sub} = Billing.set_subscription(player, "companion_1499")
      assert sub.tier_id == "companion_1499"
      assert sub.price_usd == 14.99
      assert sub.tier_name =~ "Companion"
      assert sub.maturity_rating == "mature"
    end

    test "activates $19.99 Archon tier and automatically awards 18+ verification", %{player: player} do
      assert {:ok, sub} = Billing.set_subscription(player, "archon_1999")
      assert sub.tier_id == "archon_1999"
      assert sub.price_usd == 19.99
      assert sub.tier_name =~ "Archon"
      assert sub.maturity_rating == "adult"
      assert sub.age_verified? == true
    end
  end
end
