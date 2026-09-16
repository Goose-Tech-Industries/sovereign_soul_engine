defmodule SovereignSoulEngineWeb.Api.RoboticsController do
  @moduledoc """
  Physical Robotics Body & ROS2 Actuation API.

  Provides physical robot companions (Unitree G1, Unitree Go2, LOVOT, ROS2 nodes)
  with real-time kinematic posture goals, joint radian targets, locomotion velocity,
  and bidirectional hardware telemetry ingestion.
  """

  use SovereignSoulEngineWeb, :controller

  alias SovereignSoulEngine.Wearables.RoboticsBridge

  @doc """
  GET /sse/api/robotics/actuation
  GET /api/robotics/actuation
  """
  def actuation(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"
    packet = RoboticsBridge.compute_actuation(character_slug)

    case packet do
      %{status: "ok"} ->
        json(conn, packet)

      %{status: "error", error: reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: reason})
    end
  end

  @doc """
  POST /sse/api/robotics/telemetry
  POST /api/robotics/telemetry
  """
  def telemetry(conn, params) do
    character_slug = params["character_slug"] || params["slug"] || "goose"

    case RoboticsBridge.ingest_telemetry(character_slug, params) do
      {:ok, result} ->
        json(conn, result)

      {:error, :character_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Character '#{character_slug}' not found."})
    end
  end
end
