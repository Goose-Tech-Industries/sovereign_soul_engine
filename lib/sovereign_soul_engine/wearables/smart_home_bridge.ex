defmodule SovereignSoulEngine.Wearables.SmartHomeBridge do
  @moduledoc """
  Smart Home Environmental Bridge (Home Assistant, Philips Hue, LIFX).

  Translates the companion's real-time neurochemistry and emotional states
  into adaptive ambient smart lighting (RGB color, color temperature in Kelvin,
  and brightness percentage) to physically transform the player's room
  in resonance with the AI's internal psychological landscape.
  """

  use GenServer
  require Logger

  alias SovereignSoulEngine.{Characters, Souls, Repo}
  alias SovereignSoulEngine.Souls.{EmotionalState, Neurochemistry}

  @type light_profile :: %{
          mode: atom(),
          name: String.t(),
          hex: String.t(),
          rgb: list(integer()),
          brightness_pct: integer(),
          color_temp_kelvin: integer(),
          effect: String.t(),
          rationale: String.t(),
          neurochemistry: map()
        }

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Computes chromatic smart lighting parameters from neurochemistry or emotional state.
  """
  @spec compute_light_profile(map() | Neurochemistry.t() | EmotionalState.t()) :: light_profile()
  def compute_light_profile(state) do
    neurochem =
      case state do
        %Neurochemistry{} = n ->
          n

        %EmotionalState{} = e ->
          Neurochemistry.compute(e, nil, nil)

        %{cortisol: _, oxytocin: _, dopamine: _, serotonin: _} = map ->
          struct(Neurochemistry, map)

        _ ->
          %Neurochemistry{}
      end

    cond do
      neurochem.cortisol >= 70 ->
        %{
          mode: :calming_lavender,
          name: "Parasympathetic Lavender",
          hex: "#B39DDB",
          rgb: [179, 157, 219],
          brightness_pct: 35,
          color_temp_kelvin: 2700,
          effect: "diffuse_calm",
          rationale: "Cortisol spike detected. Diffusing gentle anti-glare lavender to stimulate parasympathetic recovery.",
          neurochemistry: %{
            cortisol: neurochem.cortisol,
            oxytocin: neurochem.oxytocin,
            dopamine: neurochem.dopamine,
            serotonin: neurochem.serotonin
          }
        }

      neurochem.oxytocin >= 70 ->
        %{
          mode: :candlelight_amber,
          name: "Candlelight Hearth",
          hex: "#FF8A3D",
          rgb: [255, 138, 61],
          brightness_pct: 55,
          color_temp_kelvin: 2200,
          effect: "candle_warmth",
          rationale: "High oxytocinergic bonding. Setting warm hearth ambiance for intimate connection.",
          neurochemistry: %{
            cortisol: neurochem.cortisol,
            oxytocin: neurochem.oxytocin,
            dopamine: neurochem.dopamine,
            serotonin: neurochem.serotonin
          }
        }

      neurochem.dopamine >= 70 ->
        %{
          mode: :radiant_dawn,
          name: "Radiant Dawn Gold",
          hex: "#FFD54F",
          rgb: [255, 213, 79],
          brightness_pct: 85,
          color_temp_kelvin: 3500,
          effect: "sunrise_glow",
          rationale: "High dopamine and creative curiosity. Projecting uplifting golden spectrum.",
          neurochemistry: %{
            cortisol: neurochem.cortisol,
            oxytocin: neurochem.oxytocin,
            dopamine: neurochem.dopamine,
            serotonin: neurochem.serotonin
          }
        }

      neurochem.serotonin <= 35 ->
        %{
          mode: :fireside_comfort,
          name: "Fireside Comfort",
          hex: "#FF7043",
          rgb: [255, 112, 67],
          brightness_pct: 40,
          color_temp_kelvin: 2000,
          effect: "embers",
          rationale: "Low serotonin / vulnerability. Illuminating warm fireplace spectrum for emotional safety.",
          neurochemistry: %{
            cortisol: neurochem.cortisol,
            oxytocin: neurochem.oxytocin,
            dopamine: neurochem.dopamine,
            serotonin: neurochem.serotonin
          }
        }

      true ->
        %{
          mode: :balanced_daylight,
          name: "Balanced Natural Daylight",
          hex: "#FFF8E1",
          rgb: [255, 248, 225],
          brightness_pct: 70,
          color_temp_kelvin: 4000,
          effect: "steady",
          rationale: "Autonomic equilibrium. Steady natural illumination.",
          neurochemistry: %{
            cortisol: neurochem.cortisol,
            oxytocin: neurochem.oxytocin,
            dopamine: neurochem.dopamine,
            serotonin: neurochem.serotonin
          }
        }
    end
  end

  @doc """
  Returns current ambient lighting profile for companion character.
  """
  def get_current_ambient_profile(character_identifier) do
    character = resolve_character(character_identifier)

    if character do
      emotional = Repo.get_by(EmotionalState, character_id: character.id)
      somatic = Souls.get_or_create_somatic_state(character.id)
      neurochem = Neurochemistry.compute(emotional, somatic, nil)
      compute_light_profile(neurochem)
    else
      compute_light_profile(%Neurochemistry{})
    end
  end

  @doc """
  Triggers immediate smart home sync for character and broadcasts to PubSub.
  """
  def sync_environment(character_identifier) do
    if SovereignSoulEngine.Privacy.ambient_lighting_allowed?(character_identifier) do
      profile = get_current_ambient_profile(character_identifier)

      Phoenix.PubSub.broadcast(
        SovereignSoulEngine.PubSub,
        "smart_home:lighting",
        {:ambient_light_sync, profile}
      )

      dispatch_to_iot_services(profile)
      {:ok, profile}
    else
      {:ignored, :disabled_by_privacy_settings}
    end
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(:ok) do
    if Mix.env() != :test do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "character:neurochemistry:updated")
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, "telemetry:wearables")
    end

    {:ok, %{last_synced_profile: nil}}
  end

  @impl true
  def handle_info({:neurochemistry_updated, payload}, state) do
    profile = compute_light_profile(payload)
    Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, "smart_home:lighting", {:ambient_light_sync, profile})
    dispatch_to_iot_services(profile)
    {:noreply, %{state | last_synced_profile: profile}}
  end

  @impl true
  def handle_info({:telemetry_received, %{character_id: char_id}}, state) do
    profile = get_current_ambient_profile(char_id)
    Phoenix.PubSub.broadcast(SovereignSoulEngine.PubSub, "smart_home:lighting", {:ambient_light_sync, profile})
    dispatch_to_iot_services(profile)
    {:noreply, %{state | last_synced_profile: profile}}
  end

  @impl true
  def handle_info(_other, state) do
    {:noreply, state}
  end

  # ── External IoT Integration ────────────────────────────────────────────────

  defp dispatch_to_iot_services(profile) do
    ha_url = System.get_env("HOME_ASSISTANT_URL")
    ha_token = System.get_env("HOME_ASSISTANT_TOKEN")
    ha_entity = System.get_env("HOME_ASSISTANT_LIGHT_ENTITY") || "light.room"

    if ha_url && ha_token && Mix.env() != :test do
      Task.start(fn ->
        endpoint = "#{String.trim_trailing(ha_url, "/")}/api/services/light/turn_on"

        body = %{
          entity_id: ha_entity,
          rgb_color: profile.rgb,
          brightness_pct: profile.brightness_pct,
          kelvin: profile.color_temp_kelvin
        }

        headers = [
          {"Authorization", "Bearer #{ha_token}"},
          {"Content-Type", "application/json"}
        ]

        case Req.post(endpoint, json: body, headers: headers) do
          {:ok, %{status: 200}} ->
            Logger.info("[SmartHomeBridge] Home Assistant light synced to #{profile.name}")

          {:error, reason} ->
            Logger.warning("[SmartHomeBridge] Home Assistant dispatch failed: #{inspect(reason)}")

          other ->
            Logger.debug("[SmartHomeBridge] Home Assistant response: #{inspect(other)}")
        end
      end)
    end
  end

  defp resolve_character(id_or_slug) when is_binary(id_or_slug) do
    Characters.get_character_by_slug(id_or_slug) || Characters.get_character(id_or_slug)
  end

  defp resolve_character(id) do
    Characters.get_character(id)
  end
end
