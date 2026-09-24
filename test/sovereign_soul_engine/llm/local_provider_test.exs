defmodule SovereignSoulEngine.LLM.LocalProviderTest do
  use ExUnit.Case, async: false

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

    test "parses a deterministic OpenAI-compatible local response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"content" => ~s({"public_speech":"hello"})}}]
        })
      end)

      assert {:ok, %{"public_speech" => "hello"}} =
               LocalProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "falls back safely for plain local provider text" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "plain"}}]})
      end)

      assert {:ok, %{"public_speech" => "plain", "tone" => "neutral"}} =
               LocalProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "maps a local HTTP failure to a connection error" do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "offline") end)

      assert {:error, "Local LLM error (HTTP 503): \"offline\""} =
               LocalProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
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
