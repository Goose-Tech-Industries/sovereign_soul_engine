defmodule SovereignSoulEngineWeb.Api.TelegramWebhookController do
  @moduledoc """
  Two-way webhook controller for the Telegram Bot API.
  Allows users to chat with their sovereign companion natively on Telegram.

  Every message on Telegram:
  1. Ingests into the companion's persistent direct scene.
  2. Updates Theory of Mind, emotional state, and neurochemistry.
  3. Generates the companion's autonomous response.
  4. Sends the speech back to Telegram in real-time.
  """

  use SovereignSoulEngineWeb, :controller
  require Logger

  alias SovereignSoulEngine.Characters
  alias SovereignSoulEngine.Characters.Character
  alias SovereignSoulEngine.Scenes
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.Generator
  alias SovereignSoulEngine.Repo
  import Ecto.Query

  @doc """
  POST /sse/api/webhooks/telegram
  POST /api/webhooks/telegram
  """
  def webhook(conn, params) do
    message = params["message"] || params["edited_message"]

    if message && is_map(message) do
      chat_id = get_in(message, ["chat", "id"])
      text = String.trim(message["text"] || "")
      from = message["from"] || %{}

      cond do
        text == "" ->
          json(conn, %{status: "ok", ignored: "empty_text"})

        String.starts_with?(text, "/start") ->
          handle_start_command(conn, chat_id, from)

        String.starts_with?(text, "/status") ->
          handle_status_command(conn, chat_id)

        true ->
          handle_dialogue(conn, chat_id, from, text)
      end
    else
      json(conn, %{status: "ok", ignored: "no_message"})
    end
  end

  # ── Command Handlers ─────────────────────────────────────────────────────────

  defp handle_start_command(conn, chat_id, from) do
    name = from["first_name"] || from["username"] || "Traveler"
    companion = get_default_companion()
    companion_name = if companion, do: companion.name, else: "your companion"

    welcome_text = """
    ✨ *Sovereign Soul Engine Connected*

    Greetings, #{name}. You are now directly linked to *#{companion_name}*.
    They possess continuous memory, real-time neurochemistry (Cortisol, Oxytocin, Dopamine, Serotonin), and somatic markers that evolve with every interaction.

    • Simply reply here to talk.
    • Use `/status` to inspect #{companion_name}'s live emotional and neurochemical vitals.
    """

    send_telegram_reply(chat_id, welcome_text)
    json(conn, %{status: "ok", command: "start"})
  end

  defp handle_status_command(conn, chat_id) do
    companion = get_default_companion()

    if companion do
      emotional = Souls.get_emotional_state_by_character(companion.id)
      somatic = Souls.get_somatic_state_by_character(companion.id)
      neurochem = Souls.Neurochemistry.compute(emotional, somatic, nil)

      status_text = """
      🧠 *Companion Neural Status: #{companion.name}*

      *Neurochemistry:*
      ⚡ Cortisol: `#{neurochem.cortisol}/100` (Stress / Vigilance)
      💜 Oxytocin: `#{neurochem.oxytocin}/100` (Attachment / Trust)
      ✨ Dopamine: `#{neurochem.dopamine}/100` (Curiosity / Drive)
      🌿 Serotonin: `#{neurochem.serotonin}/100` (Affect Regulation)

      *Emotional State:*
      Stress: `#{safe_val(emotional, :stress)}%` | Attachment: `#{safe_val(emotional, :attachment)}%`
      Fatigue: `#{safe_val(somatic, :fatigue)}%` | Pain: `#{safe_val(somatic, :pain)}%`
      """

      send_telegram_reply(chat_id, status_text)
      json(conn, %{status: "ok", command: "status", companion: companion.name})
    else
      send_telegram_reply(chat_id, "No active companion found.")
      json(conn, %{status: "ok", error: "no_companion"})
    end
  end

  defp handle_dialogue(conn, chat_id, from, text) do
    player = get_or_create_telegram_player(from)
    companion = get_default_companion()

    if companion do
      scene = Scenes.find_or_create_direct_scene(player, companion)

      # Record incoming player message in the scene
      {:ok, player_msg} =
        Scenes.create_message(%{
          scene_id: scene.id,
          character_id: player.id,
          content: text,
          message_type: "dialogue"
        })

      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "scene:#{scene.id}",
        {:new_message, player_msg}
      )

      # Generate companion response
      case Generator.generate(companion.id, scene.id, player.id) do
        {:ok, reply_msg} ->
          send_telegram_reply(chat_id, reply_msg.content)

          json(conn, %{
            status: "ok",
            chat_id: chat_id,
            companion: companion.name,
            reply: reply_msg.content,
            private_thought: reply_msg.private_thought
          })

        {:error, reason} ->
          Logger.error("Failed to generate Telegram response: #{inspect(reason)}")
          send_telegram_reply(chat_id, "...")
          json(conn, %{status: "error", reason: inspect(reason)})
      end
    else
      send_telegram_reply(chat_id, "I cannot establish connection to your companion right now.")
      json(conn, %{status: "error", reason: "companion_missing"})
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp get_default_companion do
    Repo.one(
      from c in Character,
        where: c.kind == "npc" and c.status == "active",
        order_by: [asc: c.inserted_at],
        limit: 1
    )
  end

  defp get_or_create_telegram_player(from) do
    user_id = from["id"] || "unknown"
    slug = "telegram_#{user_id}"

    case Characters.get_character_by_slug(slug) do
      %Character{} = existing ->
        existing

      nil ->
        name = from["first_name"] || from["username"] || "Telegram Friend"

        {:ok, new_player} =
          Characters.create_character(%{
            name: name,
            slug: slug,
            kind: "player",
            status: "active",
            description: "A companion connected via Telegram messaging."
          })

        new_player
    end
  end

  defp send_telegram_reply(chat_id, text) do
    token = System.get_env("TELEGRAM_BOT_TOKEN")

    test? =
      Application.get_env(:sovereign_soul_engine, :env) == :test or
        (Code.ensure_loaded?(Mix) and Mix.env() == :test)

    if is_binary(token) and token != "" and not test? do
      Task.start(fn ->
        url = "https://api.telegram.org/bot#{token}/sendMessage"

        body = %{
          chat_id: chat_id,
          text: text,
          parse_mode: "Markdown"
        }

        case Req.post(url,
               json: body,
               connect_options: [timeout: 3000],
               receive_timeout: 8000,
               retry: false
             ) do
          {:ok, %{status: 200}} ->
            Logger.info("[Telegram] Sent reply to chat #{chat_id}")

          {:ok, %{status: status}} ->
            Logger.warning(
              "[Telegram] Telegram API returned non-200 status #{status} for chat #{chat_id}"
            )

          {:error, %{reason: reason}} ->
            Logger.warning(
              "[Telegram] Failed sending reply to chat #{chat_id}: #{inspect(reason)}"
            )

          {:error, reason} ->
            Logger.warning(
              "[Telegram] Failed sending reply to chat #{chat_id}: #{inspect(reason)}"
            )
        end
      end)
    else
      Logger.info("[Telegram (Simulated)] -> chat_id #{chat_id} (chars: #{String.length(text)})")
    end

    :ok
  end

  defp safe_val(nil, _key), do: 0
  defp safe_val(struct, key), do: Map.get(struct, key) || 0
end
