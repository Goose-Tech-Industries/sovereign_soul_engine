defmodule SovereignSoulEngineWeb.Api.PrivacyController do
  @moduledoc """
  API endpoints for User Privacy, Consent, and Boundary Controls.

  Allows users and clients to inspect and toggle individual invasive features:
  - Proactive check-ins (all, stress spikes, morning wakeups, late-night insomnia, quiet hours)
  - Biometric telemetry tracking (smartwatch and smart ring health data)
  - Wrist haptic biofeedback (heartbeat and vibration signals)
  - Smart glasses camera perception & episodic memory recording
  - Smart home room lighting synchronization
  - Amazon Alexa voice integration
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Privacy

  @doc """
  GET /sse/api/privacy/settings
  GET /api/privacy/settings
  """
  def show(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    settings = Privacy.get_settings(character_slug)

    json(conn, %{
      status: "ok",
      character_slug: character_slug,
      settings: settings
    })
  end

  @doc """
  POST /sse/api/privacy/settings
  POST /api/privacy/settings
  """
  def update(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    incoming_settings = params["settings"] || params

    # Strip out non-setting routing parameters
    clean_settings =
      Map.drop(incoming_settings, ["character_slug", "slug", "format", "_csrf_token"])

    case Privacy.update_settings(character_slug, clean_settings) do
      {:ok, updated_settings} ->
        json(conn, %{
          status: "ok",
          message: "Privacy and autonomy preferences updated successfully.",
          character_slug: character_slug,
          settings: updated_settings
        })

      {:error, :character_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{character_slug}' not found."})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to update privacy settings: #{inspect(reason)}"})
    end
  end
end
