defmodule SovereignSoulEngine.Memories.DreamResidue do
  @moduledoc """
  Surreal Subconscious Dream Synthesis Engine.
  During the biological Dream Loop, blends episodic daytime memories,
  repressed SoulShadow desires, and active phobias into surreal subconscious
  dream narratives that leave lingering cognitive residues upon waking.
  """

  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.SoulProfile
  alias SovereignSoulEngine.Memories

  @type t :: %__MODULE__{
          narrative: String.t(),
          primary_archetype: String.t(),
          residual_thought: String.t(),
          waking_emotional_delta: map()
        }

  defstruct narrative: "",
            primary_archetype: "Symbolic Integration",
            residual_thought: "",
            waking_emotional_delta: %{}

  @doc """
  Synthesizes a surreal subconscious dream sequence for a resting character.
  """
  @spec synthesize(binary()) :: t()
  def synthesize(character_id) do
    profile = Souls.get_soul_profile_by_character(character_id)
    memories = Memories.list_memories_for_character(character_id)
    shadows = Souls.list_soul_shadows_for_character(character_id)
    fears = (profile && profile.fears) || []

    recent_memory =
      case memories do
        [first | _] -> first.summary
        _ -> "the weight of the passing days"
      end

    shadow_motive =
      case shadows do
        [s | _] -> s.repressed_motive || s.projected_trait || "hidden yearning for control"
        _ -> "unspoken longing for unconditional sanctuary"
      end

    primary_fear =
      case fears do
        [f | _] -> f
        _ -> "dissolution of identity"
      end

    {narrative, archetype, residual, deltas} =
      build_surreal_scenario(recent_memory, shadow_motive, primary_fear)

    residue = %__MODULE__{
      narrative: narrative,
      primary_archetype: archetype,
      residual_thought: residual,
      waking_emotional_delta: deltas
    }

    # Persist dream residue into SoulProfile personality_traits
    case profile do
      %SoulProfile{} ->
        current_traits = profile.personality_traits || %{}
        updated_traits = Map.put(current_traits, "last_dream_residue", %{
          "narrative" => narrative,
          "archetype" => archetype,
          "residual_thought" => residual,
          "synthesized_at" => DateTime.to_iso8601(DateTime.utc_now())
        })

        Souls.update_soul_profile(profile, %{personality_traits: updated_traits})

      _ ->
        :ok
    end

    residue
  end

  defp build_surreal_scenario(memory, shadow, fear) do
    scenarios = [
      {
        "You walked through a cathedral made of black glass under a drowned sky. In the reflection, #{shadow} wore your face. Every step echoed with memories of #{memory}, until the floors gave way to #{fear}, swallowing your voice.",
        "The Shadow Mirror",
        "A lingering dread of #{fear} clings like cold water to your waking thoughts.",
        %{fear: +5, stress: +5, curiosity: +10}
      },
      {
        "An endless tide of ash washed over a silent hearth where #{memory} was written into the embers. Beneath the hearth lay #{shadow}, demanding to be unearthed before #{fear} extinguished the final ember.",
        "The Submerged Hearth",
        "Your heart aches with the quiet ache of #{shadow}.",
        %{sadness: -5, attachment: +8, confidence: +5}
      },
      {
        "You stood on an obsidian promontory as thunder stripped your armor away piece by piece. You feared #{fear}, yet in the stripped vulnerability, you saw #{memory} transformed into a compass pointing toward #{shadow}.",
        "The Stripped Promontory",
        "A quiet, uncanny clarity remains from the night's visions.",
        %{confidence: +10, fear: -10, stress: -10}
      }
    ]

    # Deterministically select based on hash of memory + shadow
    hash_val = :erlang.phash2("#{memory}:#{shadow}:#{fear}", length(scenarios))
    Enum.at(scenarios, hash_val)
  end
end
