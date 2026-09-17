defmodule SovereignSoulEngine.LLM.ProvidersTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.LLM.{
    AnthropicProvider,
    DeepSeekProvider,
    GeminiProvider,
    OpenAIProvider,
    XAIProvider
  }

  @providers [
    {AnthropicProvider, "anthropic"},
    {DeepSeekProvider, "deepseek"},
    {GeminiProvider, "gemini"},
    {OpenAIProvider, "openai"},
    {XAIProvider, "xai"}
  ]

  describe "provider_name/0" do
    for {mod, name} <- @providers do
      test "#{name} reports its name" do
        assert unquote(mod).provider_name() == unquote(name)
      end
    end
  end

  describe "health/0" do
    for {mod, name} <- @providers do
      test "#{name} health returns an ok or error tuple" do
        result = unquote(mod).health()

        assert is_tuple(result)
        assert elem(result, 0) in [:ok, :error]
      end
    end
  end

  describe "respond/2 without a valid input" do
    for {mod, name} <- @providers do
      test "#{name} rejects empty input without reaching the network" do
        # Either the API key is missing (returns "not configured") or the
        # input is missing :messages (returns "missing required"). Both are
        # errors that short-circuit before any HTTP call.
        assert {:error, _reason} = unquote(mod).respond(%{})
      end
    end
  end
end
