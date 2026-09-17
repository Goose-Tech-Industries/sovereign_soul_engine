# Seeds the 50 founding souls of the Soul Society world.
#
#   mix run priv/repo/seeds/seed_souls.exs

alias SovereignSoulEngine.World

case World.seed_souls() do
  {:ok, count} ->
    IO.puts("Seeded #{count} souls into the Soul Society.")

  _ ->
    IO.puts("Soul Society seeding failed.")
end
