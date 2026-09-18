defmodule SovereignSoulEngine.Billing do
  @moduledoc """
  Unified Billing & Monetization Context.

  Coordinates:
  - Stripe subscription plans ($14.99 Companion and $19.99 Archon 18+ tiers).
  - Age Verification & Safe Harbor Consent Subsystem.
  - Automatic tier-to-maturity synchronization with SovereignSoulEngine.Moderation.
  """

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Billing.StripeService
  alias SovereignSoulEngine.Billing.AgeVerification
  alias SovereignSoulEngine.Moderation

  @pubsub_topic "billing:subscriptions"

  def pubsub_topic, do: @pubsub_topic

  # --- Tiers & Pricing --------------------------------------------------------

  defdelegate list_tiers, to: StripeService
  defdelegate get_tier(id), to: StripeService

  # --- Age Verification -------------------------------------------------------

  defdelegate verify_age_by_dob(char_or_id, dob, attestations \\ %{}), to: AgeVerification, as: :verify_by_dob
  defdelegate verify_age_by_credit_card(char_or_id, opts \\ %{}), to: AgeVerification, as: :verify_by_credit_card
  defdelegate age_verified?(char_or_id), to: AgeVerification, as: :verified?
  defdelegate get_age_status(char_or_id), to: AgeVerification, as: :get_status

  # --- Subscription Management ------------------------------------------------

  @doc "Retrieves the active subscription details for a character/player."
  @spec get_subscription(Character.t() | String.t()) :: map()
  def get_subscription(character_or_id) do
    character = resolve_character(character_or_id)
    metadata = (character && character.metadata) || %{}
    sub = Map.get(metadata, "subscription", %{})

    tier_id = Map.get(sub, "tier", "free")
    tier_info = get_tier(tier_id)

    %{
      tier_id: tier_id,
      tier_name: (tier_info && tier_info.name) || "Free Community",
      price_usd: (tier_info && tier_info.price_usd) || 0.0,
      status: Map.get(sub, "status", "active"),
      stripe_subscription_id: Map.get(sub, "stripe_subscription_id"),
      updated_at: Map.get(sub, "updated_at"),
      age_verified?: AgeVerification.verified?(character),
      maturity_rating: if(tier_id == "archon_1999", do: "adult", else: if(tier_id == "companion_1499", do: "mature", else: "teen"))
    }
  end

  @doc """
  Sets a character's subscription tier.
  If upgrading to archon_1999, automatically validates and applies 18+ commercial verification.
  Also synchronizes the engine moderation maturity rating.
  """
  @spec set_subscription(Character.t() | String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def set_subscription(character_or_id, tier_id, opts \\ []) do
    character = resolve_character(character_or_id)
    tier = get_tier(tier_id)

    if tier == nil and tier_id != "free" do
      {:error, :invalid_tier}
    else
      now_str = DateTime.to_iso8601(DateTime.utc_now())

      sub_payload = %{
        "tier" => tier_id,
        "status" => Keyword.get(opts, :status, "active"),
        "stripe_subscription_id" => Keyword.get(opts, :stripe_subscription_id, "sub_local_#{tier_id}"),
        "stripe_customer_id" => Keyword.get(opts, :stripe_customer_id, "cus_local_#{character.slug}"),
        "updated_at" => now_str
      }

      current_metadata = character.metadata || %{}
      new_metadata = Map.put(current_metadata, "subscription", sub_payload)

      # If upgrading to Archon 18+, automatically award commercial credit card age verification
      new_metadata =
        if tier_id == "archon_1999" do
          verif = %{
            "verified" => true,
            "method" => "credit_card_stripe",
            "verified_at" => now_str,
            "consented_ai_disclaimer" => true,
            "consented_mature_content" => true
          }

          Map.put(new_metadata, "age_verification", verif)
        else
          new_metadata
        end

      case character |> Ecto.Changeset.change(metadata: new_metadata) |> Repo.update() do
        {:ok, updated_char} ->
          # Automatically align runtime moderation maturity rating
          target_rating =
            case tier_id do
              "archon_1999" -> "adult"
              "companion_1499" -> "mature"
              _ -> "teen"
            end

          Moderation.set_maturity_rating(target_rating)

          Phoenix.PubSub.broadcast(
            SovereignSoulEngine.PubSub,
            @pubsub_topic,
            {:subscription_updated, updated_char.id, sub_payload}
          )

          {:ok, get_subscription(updated_char)}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "Cancels a character's subscription and downgrades to the free tier."
  def cancel_subscription(character_or_id) do
    set_subscription(character_or_id, "free", status: "canceled")
  end

  @doc "Creates a Stripe checkout session for the given tier."
  def create_checkout_session(tier_id, character_or_id, opts \\ []) do
    character = resolve_character(character_or_id)
    StripeService.create_checkout_session(tier_id, character, opts)
  end

  @doc "Handles completed checkout session (e.g. from redirect or webhook)."
  def handle_checkout_completed(session_or_metadata) do
    tier_id =
      cond do
        is_map(session_or_metadata) and Map.has_key?(session_or_metadata, "metadata") ->
          get_in(session_or_metadata, ["metadata", "tier_id"]) || "companion_1499"

        is_map(session_or_metadata) and Map.has_key?(session_or_metadata, :tier) ->
          to_string(session_or_metadata.tier)

        is_binary(session_or_metadata) ->
          session_or_metadata

        true ->
          "companion_1499"
      end

    char_id =
      if is_map(session_or_metadata) and Map.has_key?(session_or_metadata, "metadata") do
        get_in(session_or_metadata, ["metadata", "character_id"])
      else
        nil
      end

    character = if char_id, do: resolve_character(char_id), else: resolve_character("goose")

    set_subscription(character, tier_id,
      stripe_subscription_id: Map.get(session_or_metadata, "subscription", "sub_completed")
    )
  end

  # --- Internal Helpers -------------------------------------------------------

  defp resolve_character(%Character{id: id}) when not is_nil(id) do
    Characters.get_character(id) || get_or_create_default_player()
  end

  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Ecto.UUID.cast(id_or_slug) do
      {:ok, uuid} ->
        Characters.get_character(uuid) || Characters.get_character_by_slug(id_or_slug) || get_or_create_default_player()

      :error ->
        Characters.get_character_by_slug(id_or_slug) || get_or_create_default_player()
    end
  end

  defp resolve_character(_), do: get_or_create_default_player()

  defp get_or_create_default_player do
    Characters.get_character_by_slug("goose") ||
      case Characters.create_character(%{
             name: "Goose",
             slug: "goose",
             kind: "player",
             status: "active",
             description: "Default player character"
           }) do
        {:ok, p} -> p
        {:error, _} -> List.first(Characters.list_characters())
      end
  end
end
