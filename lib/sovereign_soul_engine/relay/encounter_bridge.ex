defmodule SovereignSoulEngine.Relay.EncounterBridge do
  @moduledoc """
  Wires verified `encounter_*` relay envelopes into the local `MeshProtocol`
  (RFC-0002 §5).

  Resolves each DID to a local character via the `soul_dids` table. When both
  souls are local it runs the full encounter (resonance, greetings, mutual
  Theory-of-Mind impressions). The signed packet is always recorded to the world
  event ledger for audit, whether or not the encounter ran locally.
  """

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Identity
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Social.MeshProtocol
  alias SovereignSoulEngine.World

  @encounter_types ~w(encounter_offer encounter_accept encounter_decline)

  @doc "True if this envelope is an encounter lifecycle message."
  @spec encounter?(map()) :: boolean()
  def encounter?(%{"type" => type}), do: type in @encounter_types
  def encounter?(_), do: false

  @doc """
  Processes a verified encounter envelope.

  Returns the `MeshProtocol.encounter/3` result when both souls are local, or
  `{:ok, :recorded_remote}` when at least one soul has no local character.
  """
  @spec process_envelope(map()) :: {:ok, term()} | {:error, term()}
  def process_envelope(envelope) do
    a = resolve_local(envelope["from"])
    b = resolve_local(envelope["to"])

    result =
      case {a, b} do
        {a, b} when not is_nil(a) and not is_nil(b) ->
          case MeshProtocol.encounter(a, b) do
            {:ok, encounter_data} = ok ->
              record_relationship(a, b, encounter_data.resonance)
              ok

            other ->
              other
          end

        _ ->
          {:ok, :recorded_remote}
      end

    record_event(envelope)
    result
  end

  defp resolve_local(nil), do: nil

  defp resolve_local(did) do
    case Identity.get_did(did) do
      nil -> nil
      soul_did -> Characters.get_character(soul_did.character_id)
    end
  end

  defp record_event(envelope) do
    World.append_event(%{
      kind: "encounter",
      from_did: envelope["from"],
      to_did: envelope["to"],
      payload: envelope["payload"] || %{},
      signature: envelope["sig"],
      retained_until: DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)
    })
  end

  defp record_relationship(a, b, resonance) do
    delta = relationship_delta(resonance)
    apply_relationship(a, b, delta)
    apply_relationship(b, a, delta)
  end

  defp relationship_delta(resonance) do
    cond do
      resonance >= 80 -> %{affinity: 5, trust: 4, respect: 3}
      resonance >= 55 -> %{affinity: 2, trust: 1, respect: 1}
      resonance >= 30 -> %{affinity: 1}
      true -> %{affinity: -2, fear: 2, anger: 1}
    end
  end

  defp apply_relationship(a, b, delta) do
    case Relationships.get_relationship(a.id, b.id) do
      nil ->
        base = %{
          source_character_id: a.id,
          target_character_id: b.id,
          relationship_type: "acquaintance",
          last_interaction_at: DateTime.utc_now()
        }

        attrs = Enum.reduce(delta, base, fn {k, v}, acc -> Map.put(acc, k, clamp_dim(k, v)) end)
        Relationships.create_relationship(attrs)

      rel ->
        attrs =
          Enum.reduce(delta, %{}, fn {k, v}, acc ->
            Map.put(acc, k, clamp_dim(k, (Map.get(rel, k) || 0) + v))
          end)
          |> Map.put(:last_interaction_at, DateTime.utc_now())

        Relationships.update_relationship(rel, attrs)
    end
  end

  defp clamp_dim(:relationship_type, v), do: v
  defp clamp_dim(_k, v) when is_integer(v), do: max(-100, min(100, v))
  defp clamp_dim(_k, v), do: v
end
