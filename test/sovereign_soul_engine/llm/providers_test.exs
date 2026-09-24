defmodule SovereignSoulEngine.LLM.ProvidersTest do
  use ExUnit.Case, async: false

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

  describe "Gemini deterministic HTTP contract" do
    test "parses a valid JSON response through a Req test plug" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => ~s({"public_speech":"hello"})}]}}
          ]
        })
      end)

      assert {:ok, %{"public_speech" => "hello"}} =
               GeminiProvider.respond(
                 %{system: "Be concise", messages: [%{role: "user", content: "Hi"}]},
                 api_key: "test-key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "turns non-JSON candidate text into a safe fallback response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "candidates" => [
            %{"content" => %{"parts" => [%{"text" => "plain response"}]}}
          ]
        })
      end)

      assert {:ok, response} =
               GeminiProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 api_key: "test-key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )

      assert response[:public_speech] == "plain response"
      assert response[:tone] == "neutral"
    end

    test "handles an unexpected candidate shape without crashing" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"candidates" => [%{"finishReason" => "STOP"}]})
      end)

      assert {:ok, response} =
               GeminiProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 api_key: "test-key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )

      assert response[:public_speech] =~ "finishReason"
    end

    test "returns an error for an unexpected top-level response" do
      Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"error" => "bad"}) end)

      assert {:error, "unexpected_response_shape"} =
               GeminiProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 api_key: "test-key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end

    test "returns a provider-specific error for an HTTP failure" do
      Req.Test.stub(__MODULE__, fn conn -> Plug.Conn.send_resp(conn, 503, "offline") end)

      assert {:error, "gemini_http_503"} =
               GeminiProvider.respond(
                 %{messages: [%{role: "user", content: "Hi"}]},
                 api_key: "test-key",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end
  end
end
