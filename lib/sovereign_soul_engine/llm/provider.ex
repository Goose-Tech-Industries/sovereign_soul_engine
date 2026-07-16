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
  """
  @callback respond(input :: map()) :: respond_result()

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
