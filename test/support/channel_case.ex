defmodule SovereignSoulEngineWeb.ChannelCase do
  @moduledoc """
  Test case for Phoenix Channels (Soul Society relay transport).
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      @endpoint SovereignSoulEngineWeb.Endpoint
    end
  end

  setup tags do
    SovereignSoulEngine.DataCase.setup_sandbox(tags)
    :ok
  end
end
