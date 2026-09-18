alias SovereignSoulEngine.Characters

IO.puts("=== ACTIVE CHARACTERS IN SOVEREIGN SOUL ENGINE ===")
Characters.list_characters()
|> Enum.filter(&(&1.kind == "npc"))
|> Enum.each(fn c ->
  IO.puts("• #{c.name} (slug: #{c.slug}, status: #{c.status}) — #{c.description}")
end)
