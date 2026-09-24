defmodule SovereignSoulEngine.World.PopulationTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngine.World.Population

  test "ensure_population is safe when the world has no active souls" do
    assert is_integer(Population.ensure_population())
    assert Population.ensure_population() >= 0
  end

  test "population server accepts ensure and unexpected messages" do
    pid =
      Process.whereis(Population) || elem(start_supervised(Population, restart: :temporary), 1)

    send(pid, :ensure)
    send(pid, {:unexpected, :message})
    Process.sleep(20)
    assert Process.alive?(pid)
  end
end
