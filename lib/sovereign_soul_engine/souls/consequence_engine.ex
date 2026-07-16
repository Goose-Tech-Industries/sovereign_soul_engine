defmodule SovereignSoulEngine.Souls.ConsequenceEngine do
  @moduledoc """
  Transactional consequence resolution engine.

  Uses Ecto.Multi to coordinate multi-step writes for a resolved interaction.
  A single interaction may produce:
    - Scene message
    - Soul event
    - Emotional state update
    - Relationship update
    - Memory
    - Action resolution
    - Ledger entries

  All writes commit together or roll back together.
  """

  alias SovereignSoulEngine.Repo

  alias SovereignSoulEngine.Scenes.SceneMessage
  alias SovereignSoulEngine.Scenes.SoulEvent
  alias SovereignSoulEngine.Souls.EmotionalState
  alias SovereignSoulEngine.Souls.EmotionEngine
  alias SovereignSoulEngine.Relationships.Relationship
  alias SovereignSoulEngine.Relationships.RelationshipEngine
  alias SovereignSoulEngine.Memories.Memory
  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.Ledger.LedgerBuilder

  import Ecto.Query

  @doc """
  Executes a full consequence resolution within an Ecto.Multi transaction.

  Required params:
    - `:character_id` — the character affected
    - `:event_type` — atom, the soul event type
    - `:event_intensity` — 0..100
    - `:source_character_id` — who caused the event
    - `:target_character_id` — who received the event
    - `:scene_id` — the scene where it occurred
    - `:correlation_id` — UUID for tying all entries together

  Optional params:
    - `:message_content` — public speech content for SceneMessage
    - `:private_thought` — private thought (not displayed publicly)
    - `:memory_candidate` — map with memory fields (summary, importance, etc.)
    - `:action_resolution` — map with action resolution fields
    - `:personality_modifiers` — map of personality trait modifiers
    - `:emotional_state` — current EmotionalState struct (fetched if not provided)
    - `:relationship` — current Relationship struct (fetched if not provided)

  Returns `{:ok, result_map}` or `{:error, failed_operation, failed_value, changes_so_far}`.
  The result_map contains the created structs keyed by the multi step name.
  """
  @spec resolve(map()) ::
          {:ok, map()}
          | {:error, atom(), any(), %{optional(atom()) => any()}}
  def resolve(params) do
    correlation_id = params[:correlation_id] || Ecto.UUID.generate()

    multi =
      Ecto.Multi.new()
      |> maybe_create_scene_message(params, correlation_id)
      |> create_soul_event(params, correlation_id)
      |> process_emotions(params, correlation_id)
      |> process_relationship(params, correlation_id)
      |> maybe_create_memory(params, correlation_id)
      |> maybe_resolve_action(params, correlation_id)

    Repo.transaction(multi)
  end

  defp maybe_create_scene_message(multi, params, correlation_id) do
    content =
      case params[:message_content] do
        val when is_binary(val) -> String.trim(val)
        val -> val
      end

    unless is_nil(content) or content == "" do
      message_attrs = %{
        scene_id: params[:scene_id],
        character_id: params[:character_id],
        content: content,
        private_thought: params[:private_thought]
      }

      multi
      |> Ecto.Multi.insert(:scene_message, SceneMessage.changeset(%SceneMessage{}, message_attrs))
      |> Ecto.Multi.run(:ledger_message, fn repo, %{scene_message: msg} ->
        entry =
          LedgerBuilder.build_event_entry(
            character_id: params[:character_id],
            scene_id: params[:scene_id],
            entry_type: :scene_message_created,
            source: "scene",
            label: "Scene Message",
            summary: "Message created in scene",
            delta: %{content: msg.content},
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    else
      multi
    end
  end

  defp create_soul_event(multi, params, correlation_id) do
    event_type = to_string(params[:event_type])

    if event_type == "speak" do
      multi
    else
      event_attrs = %{
        scene_id: params[:scene_id],
        source_character_id: params[:source_character_id],
        target_character_id: params[:target_character_id],
        event_type: event_type,
        intensity: params[:event_intensity] || 50,
        occurred_at: DateTime.utc_now(),
        correlation_id: correlation_id
      }

      multi
      |> Ecto.Multi.insert(:soul_event, SoulEvent.changeset(%SoulEvent{}, event_attrs))
      |> Ecto.Multi.run(:ledger_event, fn repo, %{soul_event: event} ->
        entry =
          LedgerBuilder.build_event_entry(
            character_id: params[:target_character_id],
            scene_id: params[:scene_id],
            event_id: event.id,
            entry_type: :event_injected,
            source: "event",
            label: "Soul Event",
            summary:
              "Soul event #{params[:event_type]} from source #{params[:source_character_id]} to target #{params[:target_character_id]}",
            delta: %{event_type: params[:event_type], intensity: event.intensity},
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    end
  end

  defp process_emotions(multi, params, correlation_id) do
    if to_string(params[:event_type]) == "speak" do
      multi
    else
      target_id = params[:target_character_id]

      multi
      |> Ecto.Multi.run(:emotional_state_before, fn repo, _ ->
        state =
          repo.get_by(EmotionalState, character_id: target_id) ||
            %EmotionalState{character_id: target_id}

        {:ok, state}
      end)
      |> Ecto.Multi.run(:emotional_state_after, fn repo,
                                                   %{emotional_state_before: state_before} ->
        current = state_to_map(state_before)

        case EmotionEngine.process_event(current, params[:event_type],
               intensity: params[:event_intensity] || 50,
               personality_modifiers: params[:personality_modifiers] || %{},
               existing_wounds: params[:existing_wounds] || 0,
               repetition_count: params[:repetition_count] || 0
             ) do
          {:ok, updated_map, _deltas} ->
            changes = map_to_emotional_changes(updated_map)

            if state_before.id do
              state_before
              |> EmotionalState.changeset(changes)
              |> repo.update()
            else
              %EmotionalState{character_id: target_id}
              |> EmotionalState.changeset(Map.put(changes, :character_id, target_id))
              |> repo.insert()
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> Ecto.Multi.run(:ledger_emotion, fn repo,
                                            %{
                                              emotional_state_before: before,
                                              emotional_state_after: after_state
                                            } ->
        entry =
          LedgerBuilder.build_emotion_change_entry(
            character_id: target_id,
            scene_id: params[:scene_id],
            before_state: state_to_map(before),
            after_state: state_to_map(after_state),
            reason: "Event: #{params[:event_type]}",
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    end
  end

  defp process_relationship(multi, params, correlation_id) do
    if to_string(params[:event_type]) == "speak" do
      multi
    else
      source_id = params[:source_character_id]
      target_id = params[:target_character_id]

      multi
      |> Ecto.Multi.run(:relationship_before, fn repo, _ ->
        rel =
          repo.one(
            from r in Relationship,
              where:
                r.source_character_id == ^target_id and
                  r.target_character_id == ^source_id
          ) ||
            %Relationship{
              source_character_id: target_id,
              target_character_id: source_id
            }

        {:ok, rel}
      end)
      |> Ecto.Multi.run(:relationship_after, fn repo, %{relationship_before: rel_before} ->
        current = rel_to_map(rel_before)

        case RelationshipEngine.process_event(current, params[:event_type],
               intensity: params[:event_intensity] || 50,
               personality_modifiers: params[:personality_modifiers] || %{},
               existing_wounds: params[:existing_wounds] || 0,
               repetition_count: params[:repetition_count] || 0
             ) do
          {:ok, updated_map, _deltas} ->
            changes = map_to_rel_changes(updated_map)
            now = DateTime.utc_now()

            if rel_before.id do
              rel_before
              |> Relationship.changeset(Map.merge(changes, %{last_interaction_at: now}))
              |> repo.update()
            else
              %Relationship{
                source_character_id: target_id,
                target_character_id: source_id
              }
              |> Relationship.changeset(
                Map.merge(changes, %{
                  source_character_id: target_id,
                  target_character_id: source_id,
                  last_interaction_at: now
                })
              )
              |> repo.insert()
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)
      |> Ecto.Multi.run(:ledger_relationship, fn repo,
                                                 %{
                                                   relationship_before: before,
                                                   relationship_after: after_rel
                                                 } ->
        entry =
          LedgerBuilder.build_relationship_change_entry(
            character_id: target_id,
            scene_id: params[:scene_id],
            relationship_id: after_rel.id,
            before_state: rel_to_map(before),
            after_state: rel_to_map(after_rel),
            reason: "Event: #{params[:event_type]} toward #{source_id}",
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    end
  end

  defp maybe_create_memory(multi, params, correlation_id) do
    memory_candidate = params[:memory_candidate]

    unless is_nil(memory_candidate) or memory_candidate == %{} do
      memory_attrs =
        memory_candidate
        |> Map.take([
          :summary,
          :details,
          :importance,
          :emotional_intensity,
          :confidence,
          :valence,
          :tags,
          :emotional_residue,
          :category
        ])
        |> Map.merge(%{
          owner_character_id: params[:target_character_id],
          subject_character_id: params[:source_character_id],
          scene_id: params[:scene_id],
          occurred_at: DateTime.utc_now(),
          decay_rate: 1.0
        })

      multi
      |> Ecto.Multi.insert(:memory, Memory.changeset(%Memory{}, memory_attrs))
      |> Ecto.Multi.run(:ledger_memory, fn repo, %{memory: mem} ->
        entry =
          LedgerBuilder.build_memory_entry(
            character_id: params[:target_character_id],
            scene_id: params[:scene_id],
            memory_id: mem.id,
            entry_type: :memory_created,
            summary: "Memory created: #{truncate(mem.summary, 80)}",
            delta: %{
              category: mem.category,
              importance: mem.importance,
              emotional_intensity: mem.emotional_intensity
            },
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    else
      multi
    end
  end

  defp maybe_resolve_action(multi, params, correlation_id) do
    action_resolution = params[:action_resolution]

    unless is_nil(action_resolution) or action_resolution == %{} do
      action_attrs =
        action_resolution
        |> Map.take([
          :proposed_action,
          :proposed_confidence,
          :proposed_reason,
          :validation_status,
          :resolved_action,
          :rejection_reason,
          :transformation_reason
        ])
        |> Map.merge(%{
          scene_id: params[:scene_id],
          character_id: params[:character_id],
          target_character_id: params[:target_character_id],
          correlation_id: correlation_id
        })

      entry_type =
        case action_attrs[:validation_status] do
          "approved" -> :action_resolved
          "rejected" -> :action_rejected
          "transformed" -> :action_resolved
          _ -> :action_proposed
        end

      multi
      |> Ecto.Multi.insert(:action_intent, ActionIntent.changeset(%ActionIntent{}, action_attrs))
      |> Ecto.Multi.run(:ledger_action, fn repo, %{action_intent: action} ->
        entry =
          LedgerBuilder.build_action_entry(
            character_id: params[:character_id],
            scene_id: params[:scene_id],
            entry_type: entry_type,
            summary: "Action #{action.validation_status}: #{action.proposed_action}",
            before_state: %{proposed: action.proposed_action},
            after_state: %{resolved: action.resolved_action, status: action.validation_status},
            delta: %{
              status: action.validation_status,
              reason: action.rejection_reason || action.transformation_reason
            },
            reason: action.rejection_reason || action.transformation_reason || "approved",
            correlation_id: correlation_id
          )

        repo.insert(entry)
      end)
    else
      multi
    end
  end

  defp state_to_map(%EmotionalState{} = state) do
    %{
      anger: state.anger || 0,
      fear: state.fear || 0,
      stress: state.stress || 0,
      gratitude: state.gratitude || 0,
      confidence: state.confidence || 0,
      sadness: state.sadness || 0,
      curiosity: state.curiosity || 0,
      attachment: state.attachment || 0
    }
  end

  defp state_to_map(map) when is_map(map) do
    %{
      anger: Map.get(map, :anger, 0),
      fear: Map.get(map, :fear, 0),
      stress: Map.get(map, :stress, 0),
      gratitude: Map.get(map, :gratitude, 0),
      confidence: Map.get(map, :confidence, 0),
      sadness: Map.get(map, :sadness, 0),
      curiosity: Map.get(map, :curiosity, 0),
      attachment: Map.get(map, :attachment, 0)
    }
  end

  defp map_to_emotional_changes(map) do
    %{
      anger: Map.get(map, :anger),
      fear: Map.get(map, :fear),
      stress: Map.get(map, :stress),
      gratitude: Map.get(map, :gratitude),
      confidence: Map.get(map, :confidence),
      sadness: Map.get(map, :sadness),
      curiosity: Map.get(map, :curiosity),
      attachment: Map.get(map, :attachment)
    }
  end

  defp rel_to_map(%Relationship{} = rel) do
    %{
      affinity: rel.affinity || 0,
      trust: rel.trust || 0,
      respect: rel.respect || 0,
      fear: rel.fear || 0,
      anger: rel.anger || 0,
      gratitude: rel.gratitude || 0,
      debt: rel.debt || 0,
      softening: rel.softening || 0,
      hardening: rel.hardening || 0,
      wound: rel.wound || 0
    }
  end

  defp rel_to_map(map) when is_map(map) do
    %{
      affinity: Map.get(map, :affinity, 0),
      trust: Map.get(map, :trust, 0),
      respect: Map.get(map, :respect, 0),
      fear: Map.get(map, :fear, 0),
      anger: Map.get(map, :anger, 0),
      gratitude: Map.get(map, :gratitude, 0),
      debt: Map.get(map, :debt, 0),
      softening: Map.get(map, :softening, 0),
      hardening: Map.get(map, :hardening, 0),
      wound: Map.get(map, :wound, 0)
    }
  end

  defp map_to_rel_changes(map) do
    %{
      affinity: Map.get(map, :affinity),
      trust: Map.get(map, :trust),
      respect: Map.get(map, :respect),
      fear: Map.get(map, :fear),
      anger: Map.get(map, :anger),
      gratitude: Map.get(map, :gratitude),
      debt: Map.get(map, :debt),
      softening: Map.get(map, :softening),
      hardening: Map.get(map, :hardening),
      wound: Map.get(map, :wound)
    }
  end

  defp truncate(nil, _), do: ""
  defp truncate(str, max), do: String.slice(str, 0, max)
end
