defmodule SovereignSoulEngine.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers.

  Every provider must implement `respond/1` which accepts a map of input
  parameters (system prompt, user messages, stream flags, etc.) and
  returns either a validated response map or an error tuple.

  Optional callbacks:
    - `health/0` — returns provider health status
    - `provider_name/0` — returns a human-readable provider identifier
  """

  @typedoc """
  Structured response from an LLM provider.

  ## Fields
    * `public_speech` — the NPC's public dialogue
    * `private_thought` — the NPC's internal monologue (never shown publicly)
    * `tone` — emotional tone label
    * `motivation` — driving motivation behind the response
    * `target_character_id` — optional UUID of the response target
    * `proposed_action` — optional action the NPC intends to take
    * `memory_candidates` — memories the NPC may form from this interaction
    * `relationship_signals` — optional directional relationship delta hints
    * `updated_description` — optional revised self-description
    * `repressed_motive` — hidden motive driving the character's shadow log
    * `active_defense` — the psychological defense mechanism in play, if any
    * `physical_tell` — an involuntary physical reaction, narrated
    * `shame_or_guilt` — "shame" | "guilt" | nil
    * `moral_tension` — narrative note on a moral line under pressure (no consumer yet — round-trips inert)
    * `conversation_state` — "continuing" | "winding_down" | "concluded"
    * `rumination_update` — what the character is now fixated on, if anything
    * `belief_challenge` — a belief that was strengthened/weakened this turn
    * `desire_update` — a desire whose urgency changed, or a new one that emerged
    * `psychological_updates` — currently just `%{acquired_fears: [String.t()]}`
    * `knowledge_update` — a fact the character learned, and about whom (may be a third party — this is how gossip propagates)
    * `goal_update` — progress/blocker/status change on an existing goal
    * `grief_response` — intensity/stage change on an active grief arc
    * `forgiveness_signal` — direction/stage change on an active forgiveness arc
  """
  @type provider_response :: %{
          public_speech: String.t(),
          private_thought: String.t(),
          tone: String.t(),
          motivation: String.t(),
          target_character_id: String.t() | nil,
          proposed_action:
            %{
              type: String.t(),
              confidence: float(),
              reason: String.t()
            }
            | nil,
          memory_candidates: [
            %{
              category: String.t(),
              summary: String.t(),
              importance: integer(),
              emotional_intensity: integer(),
              valence: float(),
              tags: [String.t()]
            }
          ],
          relationship_signals:
            %{
              optional(String.t()) => integer()
            }
            | nil,
          updated_description: String.t() | nil,
          repressed_motive: String.t() | nil,
          active_defense: String.t() | nil,
          physical_tell: String.t() | nil,
          shame_or_guilt: String.t() | nil,
          moral_tension: String.t() | nil,
          conversation_state: String.t() | nil,
          rumination_update: %{subject: String.t() | nil, intensity: integer()} | nil,
          belief_challenge:
            %{belief: String.t() | nil, direction: String.t() | nil, conviction_delta: integer()} | nil,
          desire_update: %{desire: String.t() | nil, urgency_delta: integer()} | nil,
          psychological_updates: %{acquired_fears: [String.t()]},
          knowledge_update:
            %{
              target_character: String.t() | nil,
              fact: String.t() | nil,
              certainty: integer(),
              is_assumption: boolean()
            }
            | nil,
          goal_update:
            %{
              goal: String.t() | nil,
              new_step: String.t() | nil,
              blocker: String.t() | nil,
              status: String.t() | nil
            }
            | nil,
          grief_response:
            %{subject: String.t() | nil, stage_shift: String.t() | nil, intensity_delta: integer()} | nil,
          forgiveness_signal:
            %{wound: String.t() | nil, direction_shift: String.t() | nil, stage_shift: String.t() | nil}
            | nil
        }

  @type provider_error :: {:error, reason :: String.t()}
  @type respond_result :: {:ok, provider_response()} | provider_error()
  @type health_result :: {:ok, map()} | {:error, String.t()}

  @doc """
  Sends a request to the LLM and returns a structured response.

  The `input` map should contain at minimum:
    - `:messages` — list of message maps with `:role` and `:content`
    - `:system` — optional system prompt string

  `opts[:api_key]`, if present, overrides the provider's own env-var key —
  this is how a tenant's BYOK key reaches the provider (see `Tenants.resolve_byok/1`).
  """
  @callback respond(input :: map(), opts :: keyword()) :: respond_result()

  @doc """
  Returns health status of the provider (connectivity, API key presence, etc.).
  """
  @callback health() :: health_result()

  @doc """
  Returns a human-readable provider name.
  """
  @callback provider_name() :: String.t()

  @optional_callbacks health: 0
end
