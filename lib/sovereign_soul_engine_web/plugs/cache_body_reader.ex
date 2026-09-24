defmodule SovereignSoulEngineWeb.Plugs.CacheBodyReader do
  @moduledoc """
  Custom body reader for Plug.Parsers that caches the raw request body in
  `conn.assigns[:raw_body]`. This enables webhook controllers (such as Stripe)
  to verify cryptographic HMAC signatures against the exact raw bytes received
  over the wire.
  """

  @spec read_body(Plug.Conn.t(), keyword()) :: {:ok, binary(), Plug.Conn.t()}
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, partial, conn} ->
        # For chunked bodies, accumulate existing chunk
        current = conn.assigns[:raw_body] || ""
        conn = Plug.Conn.assign(conn, :raw_body, current <> partial)
        {:more, partial, conn}

      other ->
        other
    end
  end
end
