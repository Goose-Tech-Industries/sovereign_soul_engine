defmodule SovereignSoulEngine.Social.GossipNetwork do
  @moduledoc """
  Social Gossip Propagation: Reputation networks for autonomous inter-NPC information sharing.

  When NPC A shares memories/events about Subject C to NPC B:
  1. NPC B calculates credibility based on their affinity and trust toward NPC A:
     Credibility = (Affinity(B->A) * 0.4) + (Trust(B->A) * 0.6)
  2. B's relationship toward Subject C is shifted proportional to A's grievance/praise:
     Delta Trust(B->C) = Delta Trust(A->C) * Credibility
  3. A second-hand episodic memory is recorded in B's memory vault.
  4. The event is recorded in the SoulLedger and broadcast to subscribers.
  """

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Relationships
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Memories
  alias SovereignSoulEngine.Ledger.LedgerBuilder
  alias SovereignSoulEngine.Privacy
  alias SovereignSoulEngine.Moderation

  require Logger

  @harmful_events ~w(betrayed_me attacked_me insulted_me threatened_me abandoned_me lied_to_me)a
  @benevolent_events ~w(ally_saved_me healed_me protected_me praised_me gave_item)a

  @doc """
  Propagates gossip from a speaker to a listener regarding a subject character.

  Parameters:
    - `speaker_id` — character ID of the NPC sharing the information
    - `listener_id` — character ID of the NPC hearing the gossip
    - `subject_id` — character ID of who the gossip is about
    - `gossip_info` — map containing `:event_type`, `:summary`, and optional `:intensity`
    - `opts` — keyword list of options (`:correlation_id`, etc.)
  """
  def propagate(speaker_id, listener_id, subject_id, gossip_info, opts \\ []) do
    correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())

    speaker = Characters.get_character(speaker_id)
    listener = Characters.get_character(listener_id)
    subject = Characters.get_character(subject_id)

    if is_nil(speaker) or is_nil(listener) or is_nil(subject) do
      {:error, :character_not_found}
    else
      if Privacy.neighborhood_share_allowed?(listener) do
        do_propagate(speaker, listener, subject, gossip_info, correlation_id)
      else
        {:error, :privacy_restricted}
      end
    end
  end

  defp do_propagate(speaker, listener, subject, gossip_info, correlation_id) do
    listener_id = listener.id
    speaker_id = speaker.id
    subject_id = subject.id

    rel_listener_to_speaker = Relationships.get_relationship(listener_id, speaker_id)
    credibility = compute_credibility(rel_listener_to_speaker)

    event_type = normalize_event_type(gossip_info[:event_type])
    summary = gossip_info[:summary] || "Shared a rumor about #{subject.name}"
    summary = Moderation.redact(summary)
    deltas = calculate_gossip_deltas(event_type, credibility, gossip_info[:intensity] || 50)

    # Apply relationship shift from listener to subject
    {:ok, updated_rel} = apply_gossip_relationship(listener_id, subject_id, deltas)

    # Record second-hand memory in listener's vault
    memory_attrs = %{
      owner_character_id: listener_id,
      subject_character_id: subject_id,
      category: "relationship",
      summary: "Word from #{speaker.name}: #{summary}",
      details: %{
        "account" => "Second-hand account heard from #{speaker.name}",
        "credibility" => round(credibility * 100)
      },
      importance: max(10, min(80, round(50 * credibility))),
      emotional_intensity: max(5, min(70, round(40 * credibility))),
      valence: if(event_type in @harmful_events, do: -0.5, else: 0.5),
      tags: ["gossip", "reputation", subject.slug, "second_hand"],
      status: "active",
      decay_rate: 1.2,
      occurred_at: DateTime.utc_now()
    }

    {:ok, memory} = Memories.create_memory(memory_attrs)

    # Log to ledger
    commit_gossip_ledger(
      listener_id,
      speaker_id,
      subject_id,
      summary,
      deltas,
      credibility,
      correlation_id
    )

    # PubSub broadcast
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "character:#{listener_id}",
      {:social_gossip_received,
       %{
         listener_id: listener_id,
         speaker_id: speaker_id,
         subject_id: subject_id,
         credibility: credibility,
         deltas: deltas,
         memory_id: memory.id
       }}
    )

    {:ok,
     %{
       listener_id: listener_id,
       speaker_id: speaker_id,
       subject_id: subject_id,
       credibility: credibility,
       deltas: deltas,
       relationship: updated_rel,
       memory: memory
     }}
  end

  @doc """
  Calculates credibility (0.05 to 1.0) of speaker from listener's perspective.
  """
  def compute_credibility(nil), do: 0.25

  def compute_credibility(%Relationship{} = rel) do
    affinity = (rel.affinity || 0) / 100.0
    trust = (rel.trust || 0) / 100.0
    respect = (rel.respect || 0) / 100.0

    raw = affinity * 0.35 + trust * 0.45 + respect * 0.20
    max(0.05, min(1.0, max(0.0, raw)))
  end

  defp calculate_gossip_deltas(event_type, credibility, intensity) do
    intensity_mult = intensity / 50.0

    cond do
      event_type in @harmful_events ->
        %{
          trust: round(-25 * credibility * intensity_mult),
          affinity: round(-20 * credibility * intensity_mult),
          fear: round(15 * credibility * intensity_mult),
          hardening: round(10 * credibility * intensity_mult)
        }

      event_type in @benevolent_events ->
        %{
          trust: round(18 * credibility * intensity_mult),
          affinity: round(15 * credibility * intensity_mult),
          respect: round(12 * credibility * intensity_mult),
          softening: round(8 * credibility * intensity_mult)
        }

      true ->
        %{
          trust: round(-5 * credibility * intensity_mult),
          affinity: round(-5 * credibility * intensity_mult)
        }
    end
  end

  defp apply_gossip_relationship(listener_id, subject_id, deltas) do
    existing = Relationships.get_relationship(listener_id, subject_id)

    if existing do
      new_attrs =
        Enum.reduce(deltas, %{}, fn {dim, delta}, acc ->
          current = Map.get(existing, dim, 0) || 0
          {min_val, max_val} = if dim == :affinity, do: {-100, 100}, else: {0, 100}
          clamped = max(min_val, min(max_val, current + delta))
          Map.put(acc, dim, clamped)
        end)
        |> Map.put(:last_interaction_at, DateTime.utc_now())

      Relationships.update_relationship(existing, new_attrs)
    else
      base_attrs =
        %{
          source_character_id: listener_id,
          target_character_id: subject_id,
          relationship_type: "reputation",
          last_interaction_at: DateTime.utc_now()
        }

      merged =
        Enum.reduce(deltas, base_attrs, fn {dim, delta}, acc ->
          {min_val, max_val} = if dim == :affinity, do: {-100, 100}, else: {0, 100}
          Map.put(acc, dim, max(min_val, min(max_val, delta)))
        end)

      Relationships.create_relationship(merged)
    end
  end

  defp commit_gossip_ledger(listener_id, speaker_id, subject_id, summary, deltas, credibility, correlation_id) do
    entry =
      LedgerBuilder.build_event_entry(
        character_id: listener_id,
        scene_id: nil,
        entry_type: :social_gossip_propagated,
        source: "gossip_network",
        label: "Reputation Gossip Propagated",
        summary: "Gossip received from #{speaker_id} regarding #{subject_id}: #{summary}",
        delta: %{
          speaker_id: speaker_id,
          subject_id: subject_id,
          credibility: credibility,
          deltas: deltas
        },
        correlation_id: correlation_id
      )

    Repo.insert(entry)
  rescue
    e ->
      Logger.warning("Could not write gossip ledger entry: #{inspect(e)}")
      :ok
  end

  defp normalize_event_type(type) when is_atom(type), do: type
  defp normalize_event_type(type) when is_binary(type), do: String.to_atom(type)
  defp normalize_event_type(_), do: :unknown_rumor
end
