# Demonstrates a .soul capsule crossing between two isolated nodes/DBs.
#
#   # machine A (default dev DB)
#   mix run tools/capsule_transfer.exs seed
#   mix run tools/capsule_transfer.exs export maya tools/maya.soul
#
#   # machine B (separate database)
#   DB_NAME=sovereign_soul_engine_dev_b mix run tools/capsule_transfer.exs import tools/maya.soul

alias SovereignSoulEngine.{Characters, Identity, Relationships, Souls, World}
alias SovereignSoulEngine.Souls.SoulCapsule

case System.argv() do
  ["seed"] ->
    {:ok, n} = World.seed_souls()

    maya = Characters.get_character_by_slug!("maya")
    ravina = Characters.get_character_by_slug!("ravina")

    case Relationships.get_relationship(maya.id, ravina.id) do
      nil ->
        Relationships.create_relationship(%{
          source_character_id: maya.id,
          target_character_id: ravina.id,
          trust: 60,
          affinity: 45,
          relationship_type: "ally"
        })

      _ ->
        :ok
    end

    IO.puts("seeded #{n} souls")

  ["export", slug, file] ->
    char = Characters.get_character_by_slug!(slug)
    {:ok, capsule} = SoulCapsule.export_capsule(char)
    File.write!(file, SoulCapsule.to_json(capsule))
    IO.puts("exported #{slug} -> #{file} (capsule_id=#{capsule["capsule_id"]})")

  ["import", file] ->
    json = File.read!(file)

    case SoulCapsule.import_capsule(json, overwrite: false) do
      {:ok, char} ->
        did = Identity.get_did_for_character(char.id)
        profile = Souls.get_soul_profile_by_character(char.id)
        rels = Relationships.list_relationships_for_source(char.id)

        IO.puts("imported #{char.name} (slug=#{char.slug}, did=#{did && did.did})")
        IO.puts("  archetype=#{profile && profile.personality_traits["archetype"]}")
        IO.puts("  relationships=#{length(rels)}")

      {:error, reason} ->
        IO.puts("IMPORT FAILED: #{inspect(reason)}")
        System.halt(1)
    end

  _ ->
    IO.puts("usage: seed | export <slug> <file> | import <file>")
end
