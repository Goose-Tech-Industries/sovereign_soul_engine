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
        {a, b} when not is_nil(a) and not is_nil(b) -> MeshProtocol.encounter(a, b)
        _ -> {:ok, :recorded_remote}
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
end
