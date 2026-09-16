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
              dispatch_outbound_push(knower, subject, content, thread)
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

  @doc """
  Dispatches outbound notification via Telegram Bot API or generic webhook if configured.
  Broadcasts outbound notification on PubSub for browser/client push listeners.
  """
  def dispatch_outbound_push(knower, subject, content, thread \\ nil) do
    # 1. PubSub broadcast for web app or service worker push listeners
    Phoenix.PubSub.broadcast(
      SovereignSoulEngine.PubSub,
      "notifications:outbound",
      {:outbound_push,
       %{
         sender_name: knower.name,
         recipient_name: subject.name,
         content: content,
         thread_id: thread && thread.id,
         timestamp: DateTime.utc_now()
       }}
    )

    # 2. Telegram Bot API integration if configured
    telegram_token = System.get_env("TELEGRAM_BOT_TOKEN")
    telegram_chat_id = System.get_env("TELEGRAM_CHAT_ID")

    if telegram_token && telegram_chat_id && Mix.env() != :test do
      Task.start(fn ->
        url = "https://api.telegram.org/bot#{telegram_token}/sendMessage"
        body = %{
          chat_id: telegram_chat_id,
          text: "💬 #{knower.name}: #{content}",
          parse_mode: "Markdown"
        }

        case Req.post(url, json: body) do
          {:ok, %{status: 200}} ->
            Logger.info("[ProactiveDispatcher] Telegram notification dispatched from #{knower.name}")

          {:error, reason} ->
            Logger.warning("[ProactiveDispatcher] Telegram notification failed: #{inspect(reason)}")

          other ->
            Logger.debug("[ProactiveDispatcher] Telegram response: #{inspect(other)}")
        end
      end)
    end

    # 3. Generic Webhook integration if configured
    webhook_url = System.get_env("OUTBOUND_WEBHOOK_URL")

    if webhook_url && Mix.env() != :test do
      Task.start(fn ->
        payload = %{
          event: "companion_proactive_checkin",
          companion: knower.name,
          user: subject.name,
          message: content,
          thread_category: thread && thread.category,
          timestamp: DateTime.utc_now()
        }

        Req.post(webhook_url, json: payload)
      end)
    end

    :ok
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
