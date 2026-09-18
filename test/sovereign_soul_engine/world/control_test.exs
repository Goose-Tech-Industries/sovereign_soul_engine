defmodule SovereignSoulEngine.World.ControlTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.World.Control

  setup do
    unless Process.whereis(Control) do
      start_supervised!(Control)
    end

    Control.resume()
    :ok
  end

  test "pauses and resumes the world" do
    refute Control.paused?()

    Control.pause()
    assert Control.paused?()

    Control.resume()
    refute Control.paused?()
  end
end
