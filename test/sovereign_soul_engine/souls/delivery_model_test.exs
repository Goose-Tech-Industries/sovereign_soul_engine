defmodule SovereignSoulEngine.Souls.DeliveryModelTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Souls.DeliveryModel

  describe "all_models/0 and get_model/1" do
    test "returns all 3 canonical delivery models" do
      models = DeliveryModel.all_models()
      assert length(models) == 3

      types = Enum.map(models, & &1.type)
      assert :in_context in types
      assert :foundation_lora in types
      assert :character_lora in types
    end

    test "can fetch models by atom or string" do
      assert {:ok, %DeliveryModel{type: :in_context}} = DeliveryModel.get_model(:in_context)
      assert {:ok, %DeliveryModel{type: :foundation_lora}} = DeliveryModel.get_model("foundation_lora")
      assert {:ok, %DeliveryModel{type: :character_lora}} = DeliveryModel.get_model("character_lora")
      assert {:error, :not_found} = DeliveryModel.get_model(:unknown)
    end
  end

  describe "token_savings/1" do
    test "returns expected prompt compression ratio" do
      assert DeliveryModel.token_savings(:in_context) == 0.0
      assert DeliveryModel.token_savings(:foundation_lora) == 0.65
      assert DeliveryModel.token_savings(:character_lora) == 0.80
      assert DeliveryModel.token_savings(:invalid) == 0.0
    end
  end

  describe "supports_maturity?/2" do
    test "checks maturity tier permissions" do
      assert DeliveryModel.supports_maturity?(:in_context, "teen")
      assert DeliveryModel.supports_maturity?(:in_context, "mature")
      refute DeliveryModel.supports_maturity?(:in_context, "adult_18_plus")

      assert DeliveryModel.supports_maturity?(:foundation_lora, "adult_18_plus")
      assert DeliveryModel.supports_maturity?(:character_lora, "adult_18_plus")
    end
  end

  describe "runtime_config/2" do
    test "generates correct runtime launch args for each engine" do
      in_ctx = DeliveryModel.runtime_config(:in_context)
      assert in_ctx.engine == "ollama_or_vllm"
      refute in_ctx.lora_enabled

      foundation = DeliveryModel.runtime_config(:foundation_lora, adapter_name: "sse_v1")
      assert foundation.lora_enabled
      assert String.contains?(foundation.vllm_flags, "sse_v1")

      char = DeliveryModel.runtime_config(:character_lora, character_slug: "maya")
      assert char.lora_enabled
      assert char.character_slug == "maya"
    end
  end

  describe "monetization_matrix/0" do
    test "provides game studio annual licensing and companion creator rev split" do
      matrix = DeliveryModel.monetization_matrix()

      assert Map.has_key?(matrix, :game_studios)
      assert Map.has_key?(matrix, :companion_creators)

      tiers = matrix.game_studios.tiers
      assert length(tiers) == 3
      assert Enum.any?(tiers, &(&1.tier == "Indie Studio"))
      assert Enum.any?(tiers, &(&1.tier == "Pro Studio"))
      assert Enum.any?(tiers, &(&1.tier == "Enterprise / AAA"))

      creators = matrix.companion_creators
      assert creators.revenue_split == "50% Platform / 50% Creator"
      assert creators.one_time_forge_fee == "$49.00 USD (covers automated cloud LoRA fine-tuning and GGUF compilation)"
    end
  end
end
