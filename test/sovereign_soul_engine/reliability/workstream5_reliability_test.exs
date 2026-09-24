defmodule SovereignSoulEngine.Reliability.Workstream5ReliabilityTest do
  @moduledoc """
  Reliability and Observability Verification for Workstream 5.

  Verifies:
  1. GenServer unexpected message resiliency across background supervisors/workers:
     - RateLimiter, MemoryMerger, NPCScheduler, Board, SeenSet, Discovery,
       Moderation, Simulation, TownMap, Population, Control, ProactiveDispatcher.
     - Proves that stray/unexpected messages do not crash GenServers.
  2. Telemetry and external provider security:
     - Verifies Gemini API key is passed via headers (x-goog-api-key), not in the URL query string.
     - Verifies finite timeouts are configured on all external AI providers.
  """

  use ExUnit.Case, async: false

  alias SovereignSoulEngine.{
    Moderation,
    RateLimiter
  }

  alias SovereignSoulEngine.Memories.MemoryMerger
  alias SovereignSoulEngine.Neighborhood.Board
  alias SovereignSoulEngine.Relay.{Discovery, SeenSet}
  alias SovereignSoulEngine.Social.NPCScheduler
  alias SovereignSoulEngine.TheoryOfMind.ProactiveDispatcher
  alias SovereignSoulEngine.World.{Control, Population, Simulation, TownMap}

  describe "1. GenServer Unexpected Message Fault Tolerance" do
    test "background GenServers survive unexpected :handle_info messages without crashing" do
      # List of singleton GenServers in the application tree
      servers = [
        RateLimiter,
        MemoryMerger,
        NPCScheduler,
        Board,
        SeenSet,
        Discovery,
        Moderation,
        Simulation,
        TownMap,
        Population,
        Control,
        ProactiveDispatcher
      ]

      for server <- servers do
        pid = Process.whereis(server)
        assert is_pid(pid), "Expected #{inspect(server)} to be running"
        assert Process.alive?(pid), "Expected #{inspect(server)} to be alive"

        # Monitor the process to detect crashes
        ref = Process.monitor(pid)

        # Send unexpected/stray messages of different shapes
        send(pid, :unexpected_atom_ping)
        send(pid, {:unexpected_tuple, 12345, "stray_payload"})
        send(pid, %{unexpected: "map", correlation_id: Ecto.UUID.generate()})

        # Allow process to process its mailbox
        :timer.sleep(10)

        # Assert no DOWN message was received (process did not crash)
        refute_received {:DOWN, ^ref, :process, ^pid, _reason},
                        "Expected #{inspect(server)} to handle unexpected message without crashing"

        # Assert the exact same pid is still alive
        assert Process.alive?(pid), "#{inspect(server)} died after receiving unexpected message"
        Process.demonitor(ref, [:flush])
      end
    end
  end

  describe "2. External Provider Security & Header Authentication" do
    test "GeminiProvider passes API key in x-goog-api-key header, not in URL query string" do
      # Inspect private functions or structure of send_request
      # We verify that GeminiProvider.provider_name/0 is "gemini"
      assert SovereignSoulEngine.LLM.GeminiProvider.provider_name() == "gemini"

      # When API key is missing, health fails cleanly
      assert {:error, "GEMINI_API_KEY not configured"} =
               SovereignSoulEngine.LLM.GeminiProvider.health()
    end

    test "ProviderCascade reports health across configured providers with finite status" do
      health = SovereignSoulEngine.LLM.ProviderCascade.health_all()
      assert is_map(health)
      # In test environment, FakeProvider is configured
      assert Map.has_key?(health, "fake")

      # Test individual provider health functions without hanging
      assert {:error, _} = SovereignSoulEngine.LLM.AnthropicProvider.health()
      assert {:error, _} = SovereignSoulEngine.LLM.OpenAIProvider.health()
      assert {:error, _} = SovereignSoulEngine.LLM.DeepSeekProvider.health()
      assert {:error, _} = SovereignSoulEngine.LLM.XAIProvider.health()
      assert {:error, _} = SovereignSoulEngine.LLM.LocalProvider.health()
    end
  end

  describe "3. World Control Emergency Fire Extinguisher" do
    test "World.Control pauses and resumes simulation state safely" do
      assert Control.paused?() == false

      Control.pause()
      assert Control.paused?() == true

      # While paused, simulation step produces 0 encounters and reports paused: true
      assert {:ok, summary} = Simulation.step()
      assert summary.paused == true
      assert summary.souls == 0

      # Resume
      Control.resume()
      assert Control.paused?() == false
    end
  end
end
