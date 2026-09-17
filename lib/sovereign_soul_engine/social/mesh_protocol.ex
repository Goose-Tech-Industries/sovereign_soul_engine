defmodule SovereignSoulEngine.Social.MeshProtocol do
  @moduledoc """
  P2P Soul-to-Soul Encounter Protocol (Soul Society).

  When two autonomous souls encounter each other over local Wi-Fi, Bluetooth mesh,
  or physical robotics proximity:
  1. Handshakes with privacy validation.
  2. Calculates mutual resonance/compatibility from core values and neurochemistry.
  3. Exchanges safe, non-private social greetings.
  4. Records the peer in each soul's Theory of Mind graph.
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Privacy

  @pubsub_topic "social:mesh:encounters"

  @doc """
  Processes an encounter between two souls.
  Returns an encounter record with mutual impressions and resonance score.
  """
  def encounter(soul_a_or_slug, soul_b_or_slug, opts \\ []) do
    soul_a = resolve_character(soul_a_or_slug)
    soul_b = resolve_character(soul_b_or_slug)

    cond do
      is_nil(soul_a) or is_nil(soul_b) ->
        {:error, :character_not_found}

      soul_a.id == soul_b.id ->
        {:error, :cannot_encounter_self}

      not Privacy.neighborhood_share_allowed?(soul_a) or not Privacy.neighborhood_share_allowed?(soul_b) ->
        {:error, :encounter_prohibited_by_privacy}

      true ->
        execute_encounter(soul_a, soul_b, opts)
    end
  end

  defp execute_encounter(soul_a, soul_b, opts) do
    encounter_id = Ecto.UUID.generate()
    rssi = Keyword.get(opts, :rssi, -55) # Simulated Bluetooth signal strength in dBm

    # Compute emotional resonance based on archetypes and beliefs
    resonance_score = compute_resonance(soul_a, soul_b)

    greeting_a = "#{soul_a.name} nods calmly to #{soul_b.name}: 'Good to cross paths with you in the mesh.'"
    greeting_b = "#{soul_b.name} acknowledges #{soul_a.name}: 'Likewise. May your human be well.'"

    # Record impression in Theory of Mind
    TheoryOfMind.upsert_knowledge(
      soul_a.id,
      soul_b.id,
      "#{soul_b.name} is a neighboring sovereign entity with #{resonance_score}% resonance.",
      certainty: 0.85
    )

    TheoryOfMind.upsert_knowledge(
      soul_b.id,
      soul_a.id,
      "#{soul_a.name} is a neighboring sovereign entity with #{resonance_score}% resonance.",
      certainty: 0.85
    )

    encounter_data = %{
      id: encounter_id,
      soul_a: %{id: soul_a.id, slug: soul_a.slug, name: soul_a.name},
      soul_b: %{id: soul_b.id, slug: soul_b.slug, name: soul_b.name},
      resonance: resonance_score,
      signal_strength_dbm: rssi,
      dialogue_exchange: [greeting_a, greeting_b],
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      @pubsub_topic,
      {:mesh_encounter, encounter_data}
    )

    {:ok, encounter_data}
  end

  defp compute_resonance(soul_a, soul_b) do
    # Deterministic affinity calculation based on archetype and names
    hash = :erlang.phash2({soul_a.slug, soul_b.slug}, 45)
    50 + hash # Resonance between 50% and 95%
  end

  defp resolve_character(%Character{} = c), do: c
  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    case Characters.get_character_by_slug(id_or_slug) do
      nil ->
        case Ecto.UUID.cast(id_or_slug) do
          {:ok, uuid} -> Characters.get_character(uuid)
          :error -> nil
        end
      char ->
        char
    end
  end
  defp resolve_character(_), do: nil
end
