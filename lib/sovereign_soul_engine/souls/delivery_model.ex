defmodule SovereignSoulEngine.Souls.DeliveryModel do
  @moduledoc """
  Architectural specification and runtime adapter manager for the 3 AI delivery models
  supported by Sovereign Soul Engine:

  1. `:in_context` — Dynamic In-Context Prompt Engine (Zero-Tuning GGUF / Cloud LLM).
     The Elixir engine injects episodic memory, circadian rhythm, somatic biometrics,
     and the dual-stream cognitive schema on the fly. Zero ML overhead.

  2. `:foundation_lora` — Sovereign Soul Foundation LoRA ("The Actor Foundation").
     A pre-trained ~30MB adapter on LLaMA 3.1 8B or Mistral 7B. Natively understands
     `<private_thought>`, `<public_speech>`, JSON intent actions, and somatic tells.
     Reduces prompt token overhead by 65%.

  3. `:character_lora` — Studio / Franchise Character LoRA ("Studio Character Forge").
     A specialized 20–50MB adapter trained on a studio's dialogue bible, voice script,
     or creator's `.soul` file. Hot-swappable per NPC in <5ms on vLLM / llama.cpp.
  """

  @type model_type :: :in_context | :foundation_lora | :character_lora

  @type t :: %__MODULE__{
          type: model_type(),
          name: String.t(),
          description: String.t(),
          base_model: String.t(),
          adapter_id: String.t() | nil,
          format: :prompt | :peft | :gguf,
          prompt_token_savings: float(),
          maturity_tiers: [String.t()],
          commercial_tier: :indie | :pro | :enterprise
        }

  defstruct [
    :type,
    :name,
    :description,
    :base_model,
    :adapter_id,
    :format,
    :prompt_token_savings,
    :maturity_tiers,
    :commercial_tier
  ]

  @raw_models %{
    in_context: %{
      type: :in_context,
      name: "Dynamic In-Context Engine",
      description:
        "Off-the-shelf base GGUF or Cloud LLM with live prompt injection of memories, grudges, and somatic telemetry. Zero ML setup.",
      base_model: "meta-llama/Meta-Llama-3.1-8B-Instruct",
      adapter_id: nil,
      format: :prompt,
      prompt_token_savings: 0.0,
      maturity_tiers: ["teen", "mature"],
      commercial_tier: :indie
    },
    foundation_lora: %{
      type: :foundation_lora,
      name: "Sovereign Soul Foundation LoRA",
      description:
        "Pre-trained Actor Foundation adapter. Teaches the base model native dual-mind cognition (<private_thought> vs <public_speech>) and JSON intent schemas with zero prompt bloat.",
      base_model: "meta-llama/Meta-Llama-3.1-8B-Instruct",
      adapter_id: "sovereign-soul-foundation-8b",
      format: :peft,
      prompt_token_savings: 0.65,
      maturity_tiers: ["teen", "mature", "adult_18_plus"],
      commercial_tier: :pro
    },
    character_lora: %{
      type: :character_lora,
      name: "Studio Character LoRA Forge",
      description:
        "Bespoke character-specific adapter trained on studio dialogue bibles, lore transcripts, or .soul exports. Hot-swappable per NPC in <5ms.",
      base_model: "meta-llama/Meta-Llama-3.1-8B-Instruct",
      adapter_id: nil,
      format: :peft,
      prompt_token_savings: 0.80,
      maturity_tiers: ["teen", "mature", "adult_18_plus"],
      commercial_tier: :enterprise
    }
  }

  @doc "Returns list of all available delivery model definitions."
  @spec all_models() :: [t()]
  def all_models do
    Enum.map(Map.values(@raw_models), &struct(__MODULE__, &1))
  end

  @doc "Fetches a specific delivery model by key (:in_context, :foundation_lora, :character_lora)."
  @spec get_model(model_type() | String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_model(type) when is_atom(type) do
    case Map.get(@raw_models, type) do
      nil -> {:error, :not_found}
      attrs -> {:ok, struct(__MODULE__, attrs)}
    end
  end

  def get_model(type_str) when is_binary(type_str) do
    case type_str do
      "in_context" -> get_model(:in_context)
      "foundation_lora" -> get_model(:foundation_lora)
      "character_lora" -> get_model(:character_lora)
      _ -> {:error, :not_found}
    end
  end

  @doc "Returns prompt token savings ratio for a model type (e.g. 0.65 = 65% reduction)."
  @spec token_savings(model_type()) :: float()
  def token_savings(type) do
    case get_model(type) do
      {:ok, %__MODULE__{prompt_token_savings: savings}} -> savings
      _ -> 0.0
    end
  end

  @doc "Validates whether the model type can deliver the requested maturity tier."
  @spec supports_maturity?(model_type(), String.t()) :: boolean()
  def supports_maturity?(type, tier) do
    case get_model(type) do
      {:ok, %__MODULE__{maturity_tiers: tiers}} ->
        tier in tiers

      _ ->
        false
    end
  end

  @doc "Generates runtime inference launch configuration for local or cloud deployment."
  @spec runtime_config(model_type(), keyword()) :: map()
  def runtime_config(type, opts \\ []) do
    case type do
      :in_context ->
        %{
          engine: "ollama_or_vllm",
          command: "ollama run llama3.1:8b",
          system_prompt_mode: :full_schema,
          lora_enabled: false,
          lora_path: nil
        }

      :foundation_lora ->
        adapter_name = Keyword.get(opts, :adapter_name, "sovereign_soul_foundation_8b")

        %{
          engine: "vllm_or_llama_cpp",
          vllm_flags:
            "--enable-lora --lora-modules #{adapter_name}=./lora_weights/#{adapter_name}",
          llama_cpp_flags: "--lora ./lora_weights/#{adapter_name}.gguf",
          system_prompt_mode: :minimal_condensed,
          lora_enabled: true,
          lora_path: "./lora_weights/#{adapter_name}"
        }

      :character_lora ->
        character_slug = Keyword.get(opts, :character_slug, "default_npc")
        adapter_path = Keyword.get(opts, :adapter_path, "./lora_weights/#{character_slug}")

        %{
          engine: "vllm_multi_lora",
          vllm_flags: "--enable-lora --max-loras 64 --max-cpu-loras 128",
          system_prompt_mode: :zero_shot_character,
          lora_enabled: true,
          lora_path: adapter_path,
          character_slug: character_slug
        }
    end
  end

  @doc """
  Commercial B2B licensing and creator monetization matrix.
  Provides the business model structure for studios and UGC creators.
  """
  @spec monetization_matrix() :: map()
  def monetization_matrix do
    %{
      game_studios: %{
        licensing_type: "Annual Title License + Revenue Share Cap (The Unreal / Wwise Model)",
        rationale:
          "Studios reject metered per-token API pricing due to unpredictable runaway costs. Predictable annual licensing provides safe budgeting.",
        tiers: [
          %{
            tier: "Indie Studio",
            price: "$499 / year per title",
            eligibility: "Revenue under $100,000 USD",
            delivery_model: :in_context,
            includes: ["Unity & Unreal SDKs", "Local GGUF engine", "Community support"]
          },
          %{
            tier: "Pro Studio",
            price: "$4,999 / year per title",
            eligibility: "Revenue between $100k - $2M USD",
            delivery_model: :foundation_lora,
            includes: [
              "Foundation LoRA weights (PEFT + GGUF)",
              "Unity/Unreal SDKs",
              "Private Discord SLA",
              "Sub-second multi-NPC relay"
            ]
          },
          %{
            tier: "Enterprise / AAA",
            price: "$24,999 / year per title (or custom deal)",
            eligibility: "Revenue above $2M USD",
            delivery_model: :character_lora,
            includes: [
              "Full Character LoRA Forge pipeline",
              "Dedicated fine-tuning on studio lore",
              "On-premise air-gapped deployment",
              "24/7 dedicated engineering"
            ]
          }
        ]
      },
      companion_creators: %{
        model: "All-Access Companion Pass ($14.99 & $19.99) + Gold Tier Engagement Pool",
        pool_allocation: "15% of total subscription revenue allocated to verified Gold Tier bots",
        platform_retained:
          "85% (funds dedicated 24/7 GPU clusters, vector memory, voice synthesis, net profit)",
        rationale:
          "Users subscribe to the entire platform (Town Map, SoulBook, Canon personas), not individual bots. Gold Tier creators earn proportional monthly distributions based on qualified message engagement.",
        tier_requirements: %{
          bronze: "Community sandbox, link-only, 0% pool",
          silver: "100+ interactions, clean record, tips eligible",
          gold:
            "1,000+ interactions, >35% 7-day retention, qualifies for Monthly Pool distributions"
        },
        one_time_forge_fee:
          "$49.00 USD (covers automated cloud LoRA fine-tuning and GGUF compilation)",
        platform_subscriptions: [
          %{
            tier: "Companion Pass",
            price: "$14.99 / month",
            features: "Full Town Map, SoulBook, all Canon & Community companions, voice TTS"
          },
          %{
            tier: "Archon 18+ Uncensored",
            price: "$19.99 / month",
            features:
              "All Companion Pass features + unmoderated local weight routing & erotic subtext"
          }
        ]
      }
    }
  end
end
