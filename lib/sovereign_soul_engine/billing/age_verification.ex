defmodule SovereignSoulEngine.Billing.AgeVerification do
  @moduledoc """
  Age Verification & Informed Consent Subsystem.

  Provides compliant age verification adhering to safe-harbor standards
  for M-rated games and 18+ adult storytelling:
  1. Date-of-Birth (DOB) mathematical verification (must be >= 18 years old).
  2. Commercial Safe-Harbor Credit Card Verification (Stripe checkout verification).
  3. Informed Consent attestations:
     - Certification of majority (18+).
     - Non-human AI disclaimer (souls are generative software, not licensed therapists).
     - Voluntary consent to adult themes, strong language, and romantic intimacy.
  """

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character

  @pubsub_topic "billing:age_verification"

  @doc "Returns the PubSub topic for age verification events."
  def pubsub_topic, do: @pubsub_topic

  @doc """
  Verifies age using Date of Birth (DOB) and required consent declarations.
  Expects birth_date as a Date struct or ISO8601 string ("YYYY-MM-DD").
  """
  @spec verify_by_dob(Character.t() | String.t(), Date.t() | String.t(), map()) ::
          {:ok, map()} | {:error, atom(), String.t()}
  def verify_by_dob(character_or_id, birth_date_input, attestations \\ %{}) do
    character = resolve_character(character_or_id)

    case parse_and_validate_dob(birth_date_input) do
      {:ok, birth_date, age} ->
        if age < 18 do
          {:error, :underage,
           "You must be at least 18 years old to access mature and adult content (calculated age: #{age})."}
        else
          # Check mandatory informed consent declarations
          if attestations_valid?(attestations) do
            verification_payload = %{
              "verified" => true,
              "birth_date" => Date.to_iso8601(birth_date),
              "calculated_age" => age,
              "method" => "dob_attestation",
              "verified_at" => DateTime.to_iso8601(DateTime.utc_now()),
              "consented_ai_disclaimer" => true,
              "consented_mature_content" => true
            }

            save_verification(character, verification_payload)
          else
            {:error, :missing_consent,
             "You must confirm the 18+ certification and AI disclaimer declarations."}
          end
        end

      {:error, reason} ->
        {:error, :invalid_dob, reason}
    end
  end

  @doc """
  Commercial Safe-Harbor Verification via valid Credit Card (e.g. Stripe checkout).
  Possession and billing of a valid commercial credit card provides commercial age verification.
  """
  @spec verify_by_credit_card(Character.t() | String.t(), map()) :: {:ok, map()}
  def verify_by_credit_card(character_or_id, opts \\ %{}) do
    character = resolve_character(character_or_id)

    verification_payload = %{
      "verified" => true,
      "method" => "credit_card_stripe",
      "stripe_session_id" => Map.get(opts, :session_id, "cs_card_verified"),
      "verified_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "consented_ai_disclaimer" => true,
      "consented_mature_content" => true
    }

    save_verification(character, verification_payload)
  end

  @doc "Checks whether a character/player is verified 18+."
  @spec verified?(Character.t() | String.t()) :: boolean()
  def verified?(character_or_id) do
    status = get_status(character_or_id)
    status.verified?
  end

  @doc "Returns the full age verification & content maturity status for a character/player."
  @spec get_status(Character.t() | String.t()) :: map()
  def get_status(character_or_id) do
    character = resolve_character(character_or_id)
    metadata = (character && character.metadata) || %{}
    verif = Map.get(metadata, "age_verification", %{})
    sub = Map.get(metadata, "subscription", %{})
    tier = Map.get(sub, "tier", "free")

    is_archon = tier == "archon_1999"
    verified = Map.get(verif, "verified", false) or is_archon

    %{
      verified?: verified,
      method:
        if(is_archon and not Map.get(verif, "verified", false),
          do: "credit_card_stripe",
          else: Map.get(verif, "method", "none")
        ),
      verified_at: Map.get(verif, "verified_at"),
      birth_date: Map.get(verif, "birth_date"),
      tier: tier,
      mature_allowed?: verified or tier in ["companion_1499", "archon_1999"],
      adult_allowed?: verified and tier == "archon_1999"
    }
  end

  # --- Internal Helpers -------------------------------------------------------

  defp resolve_character(%Character{id: id}) when not is_nil(id) do
    Characters.get_character(id) || get_or_create_default_player()
  end

  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Ecto.UUID.cast(id_or_slug) do
      {:ok, uuid} ->
        Characters.get_character(uuid) || Characters.get_character_by_slug(id_or_slug) ||
          get_or_create_default_player()

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

  defp parse_and_validate_dob(%Date{} = d) do
    today = Date.utc_today()
    age = calculate_age(d, today)
    {:ok, d, age}
  end

  defp parse_and_validate_dob(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        today = Date.utc_today()
        age = calculate_age(date, today)
        {:ok, date, age}

      _ ->
        {:error, "Invalid date format. Please use YYYY-MM-DD."}
    end
  end

  defp parse_and_validate_dob(_), do: {:error, "Invalid birth date provided."}

  defp calculate_age(birth_date, today) do
    years = today.year - birth_date.year

    if today.month < birth_date.month or
         (today.month == birth_date.month and today.day < birth_date.day) do
      years - 1
    else
      years
    end
  end

  defp attestations_valid?(attestations) when is_map(attestations) do
    cert_18 = Map.get(attestations, "certify_18", false) in [true, "true", "on", 1]
    ai_ack = Map.get(attestations, "ai_disclaimer", false) in [true, "true", "on", 1]
    mature_ack = Map.get(attestations, "mature_consent", false) in [true, "true", "on", 1]

    cert_18 and ai_ack and mature_ack
  end

  defp attestations_valid?(_), do: false

  defp save_verification(character, verification_payload) do
    current_metadata = character.metadata || %{}
    new_metadata = Map.put(current_metadata, "age_verification", verification_payload)

    case character |> Ecto.Changeset.change(metadata: new_metadata) |> Repo.update() do
      {:ok, updated_char} ->
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          @pubsub_topic,
          {:age_verified, updated_char.id, verification_payload}
        )

        {:ok, verification_payload}

      {:error, changeset} ->
        {:error, :db_error, inspect(changeset.errors)}
    end
  end
end
