defmodule SovereignSoulEngineWeb.UserSocket do
  use Phoenix.Socket

  alias SovereignSoulEngine.Tenants
  alias SovereignSoulEngine.RateLimiter

  channel "soul:*", SovereignSoulEngineWeb.SoulChannel
  channel "encounter:*", SovereignSoulEngineWeb.SoulChannel
  channel "world:sovereign-society", SovereignSoulEngineWeb.SoulChannel

  @connect_limit_per_minute 30

  @impl true
  def connect(params, socket, connect_info) do
    cond do
      not rate_limit_ok?(connect_info) ->
        :error

      true ->
        case authenticate(params) do
          {:ok, tenant} ->
            {:ok, assign(socket, :tenant, tenant)}

          :open ->
            {:ok, socket}

          :error ->
            :error
        end
    end
  end

  @impl true
  def id(_socket), do: nil

  # In production a connection must present a valid tenant API key. In dev the
  # socket is open so self-sovereign DID demos (DB-free souls) keep working.
  defp authenticate(params) do
    if Application.get_env(:sovereign_soul_engine, :require_connect_auth, false) do
      case params["api_key"] do
        key when is_binary(key) and byte_size(key) > 0 ->
          case Tenants.authenticate(key) do
            %Tenants.Tenant{} = tenant -> {:ok, tenant}
            _ -> :error
          end

        _ ->
          :error
      end
    else
      case params["api_key"] do
        key when is_binary(key) and byte_size(key) > 0 ->
          case Tenants.authenticate(key) do
            %Tenants.Tenant{} = tenant -> {:ok, tenant}
            _ -> :open
          end

        _ ->
          :open
      end
    end
  end

  # Per-IP connection throttle, reusing the in-memory RateLimiter so a single
  # host cannot open a flood of sockets.
  defp rate_limit_ok?(connect_info) do
    case connect_info[:peer_data] do
      %{address: address} ->
        ip = format_ip(address)
        RateLimiter.check("connect:" <> ip, @connect_limit_per_minute) == :ok

      _ ->
        true
    end
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(ip) when is_binary(ip), do: ip
  defp format_ip(_), do: "unknown"
end
