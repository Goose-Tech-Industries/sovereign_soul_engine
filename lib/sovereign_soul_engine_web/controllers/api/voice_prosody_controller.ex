defmodule SovereignSoulEngineWeb.Api.VoiceProsodyController do
  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Voice.ProsodyEngine
  alias SovereignSoulEngine.Characters

  @doc """
  GET /sse/api/voice/prosody
  GET /api/voice/prosody
  """
  def prosody(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    character = Characters.get_character_by_slug(character_slug)

    prosody = ProsodyEngine.compute_prosody(character || %{})

    json(conn, %{
      status: "ok",
      character_slug: character_slug,
      prosody: prosody
    })
  end

  @doc """
  POST /sse/api/voice/synthesize
  POST /api/voice/synthesize
  """
  def synthesize(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    text = params["text"] || "I am feeling quite grounded tonight."
    text = SovereignSoulEngine.Moderation.redact(text)

    case ProsodyEngine.synthesize_speech(text, character_slug) do
      {:ok, result} ->
        json(conn, %{
          status: "ok",
          character_slug: character_slug,
          audio_url: result.audio_url,
          bytes: result.bytes
        })

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end
end
