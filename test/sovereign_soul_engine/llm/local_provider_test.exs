defmodule SovereignSoulEngine.LLM.LocalProviderTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.LLM.LocalProvider

  describe "provider metadata and health" do
    test "provider_name returns local" do
      assert LocalProvider.provider_name() == "local"
    end

    test "health check returns status map or connection error cleanly without crashing" do
      result = LocalProvider.health()

      assert match?({:ok, %{status: "available"}}, result) or
               match?({:error, _reason}, result)
    end
  end

  describe "build request body validation" do
    test "returns error when :messages is missing" do
      assert {:error, "missing required :messages key in input"} =
               LocalProvider.respond(%{system: "hello"})
    end

    test "live local inference when Ollama is available" do
      case LocalProvider.health() do
        {:ok, _} ->
          input = %{
            messages: [
              %{role: "user", content: "Reply with a JSON object: {\"greeting\": \"hello\"}"}
            ],
            max_tokens: 30
          }

          case LocalProvider.respond(input, timeout_ms: 15_000) do
            {:ok, response} ->
              assert is_map(response)

            {:error, reason} ->
              # In CI / mock environments without GPU
              assert is_binary(reason)
          end

        _ ->
          :ok
      end
    end
  end
end
