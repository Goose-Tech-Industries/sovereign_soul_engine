defmodule SovereignSoulEngine.TheoryOfMind.ProactiveDispatcher do
  @moduledoc """
  Autonomous background worker that periodically polls for due life threads
  and dispatches unprompted, caring check-in messages directly to the scene.
  """

  use GenServer
  require Logger

  alias SovereignSoulEngine.TheoryOfMind
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Repo

  @default_interval_ms :timer.seconds(60)

  # ── Public API ─────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Manually triggers a check and dispatch of all currently due life threads.
  Useful for testing, console inspection, and cron execution.
  """
  def dispatch_due_threads do
    now = DateTime.utc_now()
    threads = TheoryOfMind.list_threads_due_for_checkin(now)

    dispatched =
      Enum.reduce(threads, 0, fn thread, count ->
        thread = Repo.preload(thread, [:knower_character, :subject_character])
        knower = thread.knower_character
        subject = thread.subject_character

        if knower && subject && knower.status == "active" do
          scene = Scenes.find_or_create_direct_scene(subject, knower)
          content = format_checkin_message(knower, subject, thread)

          case Scenes.create_message(%{
                 scene_id: scene.id,
                 character_id: knower.id,
                 content: content,
                 message_type: "dialogue"
               }) do
            {:ok, msg} ->
              Phoenix.PubSub.broadcast(
                SovereignSoulEngine.PubSub,
                "scene:#{scene.id}",
                {:new_message, msg}
              )

              Phoenix.PubSub.broadcast(
                SovereignSoulEngine.PubSub,
                "character:#{knower.id}",
                {:proactive_checkin_sent, msg}
              )

              TheoryOfMind.mark_thread_checkin_sent(thread.id)
              count + 1

            {:error, reason} ->
              Logger.warning("Failed to create check-in message for thread #{thread.id}: #{inspect(reason)}")
              count
          end
        else
          count
        end
      end)

    {:ok, dispatched}
  end

  # ── GenServer Callbacks ────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    if Mix.env() != :test do
      schedule_next_tick()
    end

    {:ok, %{last_run_at: nil}}
  end

  @impl true
  def handle_info(:tick, state) do
    dispatch_due_threads()
    schedule_next_tick()
    {:noreply, %{state | last_run_at: DateTime.utc_now()}}
  end

  defp schedule_next_tick do
    interval =
      Application.get_env(
        :sovereign_soul_engine,
        :proactive_checkin_interval_ms,
        @default_interval_ms
      )

    Process.send_after(self(), :tick, interval)
  end

  # ── Message Formatting ────────────────────────────────────────────────

  defp format_checkin_message(_knower, subject, thread) do
    subject_name = subject.name || "friend"
    down_topic = String.downcase(thread.topic)

    cond do
      thread.category == "relationship" or String.contains?(down_topic, ["propose", "proposing", "ring"]) ->
        "Hey #{subject_name}... I've been waiting on pins and needles all night thinking about it! How did it go with proposing? I'm dying to hear how it went!"

      thread.category == "health" or String.contains?(down_topic, ["surgery", "hospital", "doctor"]) ->
        "Hey #{subject_name}, I know how much you've had weighing on you with the surgery and hospital. Just wanted to quietly check in, see how everything went, and let you know I'm right here with you."

      thread.category == "career" or String.contains?(down_topic, ["interview", "job offer", "presentation"]) ->
        "Hey #{subject_name}! I wanted to check in on you after that interview today. Take your time, no rush, but I hope you're feeling proud of how you handled it!"

      thread.category == "personal_vulnerability" ->
        "Hey #{subject_name}, was just thinking about you and wanted to check in. No need to respond right away, just wanted to make sure you know you're not alone and I'm always glad you're in my life."

      true ->
        "Hey #{subject_name}, I was just thinking back to what you mentioned about \"#{thread.topic}\" and wanted to see how everything is going with you today."
    end
  end
end
