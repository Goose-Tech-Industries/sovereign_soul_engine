defmodule SovereignSoulEngineWeb.Api.SmartHomeController do
  @moduledoc """
  API endpoints for Smart Home Environmental synchronization.
  Integrates with Home Assistant, Philips Hue, LIFX, or custom ambient lighting devices.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Wearables.SmartHomeBridge

  @doc """
  GET /sse/api/smart_home/ambient
  GET /api/smart_home/ambient
  """
  def ambient(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    profile = SmartHomeBridge.get_current_ambient_profile(character_slug)

    json(conn, %{
      status: "ok",
      character_slug: character_slug,
      lighting: %{
        mode: profile.mode,
        name: profile.name,
        hex: profile.hex,
        rgb: profile.rgb,
        brightness_pct: profile.brightness_pct,
        color_temp_kelvin: profile.color_temp_kelvin,
        effect: profile.effect,
        rationale: profile.rationale
      },
      neurochemistry: profile.neurochemistry
    })
  end

  @doc """
  POST /sse/api/smart_home/sync
  POST /api/smart_home/sync
  """
  def sync(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case SmartHomeBridge.sync_environment(character_slug) do
      {:ok, profile} ->
        json(conn, %{
          status: "ok",
          synced: true,
          character_slug: character_slug,
          lighting: %{
            mode: profile.mode,
            name: profile.name,
            hex: profile.hex,
            rgb: profile.rgb,
            brightness_pct: profile.brightness_pct,
            color_temp_kelvin: profile.color_temp_kelvin,
            effect: profile.effect,
            rationale: profile.rationale
          },
          neurochemistry: profile.neurochemistry
        })

      {:ignored, :disabled_by_privacy_settings} ->
        json(conn, %{
          status: "ignored_by_privacy_settings",
          synced: false,
          character_slug: character_slug,
          message: "Smart home ambient lighting is disabled in user privacy settings."
        })
    end
  end
end
