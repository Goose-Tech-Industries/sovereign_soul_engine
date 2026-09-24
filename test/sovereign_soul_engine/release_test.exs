defmodule SovereignSoulEngine.ReleaseTest do
  use SovereignSoulEngine.DataCase, async: false

  test "release migration entrypoint loads the configured repository" do
    assert is_list(SovereignSoulEngine.Release.migrate())
  end
end
