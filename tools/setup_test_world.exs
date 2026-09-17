alias SovereignSoulEngine.{Repo, Characters, Scenes, Messages}
alias SovereignSoulEngine.Scenes.{Scene, SceneParticipant, SceneMessage}
import Ecto.Query

# 1. Find or create the scene
scene =
  case Repo.get_by(Scene, title: "Bastion girls") do
    nil ->
      case Repo.get_by(Scene, title: "Test World — Town Commons") do
        nil ->
          {:ok, s} =
            Scenes.create_scene(%{
              title: "Test World — Town Commons",
              location: "Town Square Commons",
              status: "active",
              context: %{"mood" => "tense debate", "weather" => "crisp overcast"}
            })
          s

        s -> s
      end

    s ->
      {:ok, updated} =
        Scenes.update_scene(s, %{
          title: "Test World — Town Commons",
          location: "Town Square Commons",
          context: %{"mood" => "tense debate", "weather" => "crisp overcast"}
        })
      updated
  end

IO.puts("Scene ready: #{scene.title} (id=#{scene.id})")

# 2. Characters to include
goose = Characters.get_character_by_slug("goose") || hd(Characters.list_characters())
maya = Characters.get_character_by_slug("maya")
ravina = Characters.get_character_by_slug("ravina")
valeria = Characters.get_character_by_slug("valeria")
corvus = Characters.get_character_by_slug("corvus")

chars = Enum.filter([goose, maya, ravina, valeria, corvus], & &1)

# Ensure participants
for c <- chars do
  case Repo.get_by(SceneParticipant, scene_id: scene.id, character_id: c.id) do
    nil ->
      Scenes.add_participant(%{
        scene_id: scene.id,
        character_id: c.id,
        joined_at: DateTime.utc_now()
      })
    _ -> :ok
  end
end

# 3. Clean existing messages in this scene and seed fresh dramatic dual-mind messages
Repo.delete_all(from m in SceneMessage, where: m.scene_id == ^scene.id)

script = [
  {
    maya,
    "The perimeter guard reported strange movement near the river last night. We need to reinforce the south gate before dusk.",
    "If Corvus panics the townspeople, morale will collapse. I have to stay calm, even if we are short on iron."
  },
  {
    corvus,
    "I checked the tracks myself, Maya. Heavy military spacing, six scouts. They aren't poachers. We double the night watch or we lose the armory.",
    "She thinks I'm jumping at shadows. But I know mercenary doctrine when I see it. I won't let another garrison burn under my watch."
  },
  {
    ravina,
    "There is no need to mobilize the town just yet. A caravan from the eastern ridge was delayed at the crossroads. They may simply be looking for dry camp.",
    "I know exactly who they are—Syndicate scouts. If Corvus rushes in with drawn blades, he'll burn my informant before nightfall."
  },
  {
    valeria,
    "The Spire ley-lines were shivering through the third hour. Whatever approaches carries an unnatural resonance—cold, deliberate, and hungry.",
    "They argue about steel and politics while the weave unravels beneath our feet. None of them can feel the ground freezing."
  },
  {
    goose,
    "We hold the gates, but Ravina investigates the scouts first. Corvus, set an ambush perimeter without sounding the alarm.",
    ""
  },
  {
    maya,
    "Agreed. I'll have the smithy stoke the hearths for spearheads. Stay watchful, everyone.",
    "A solid decision. Goose has instincts for command. I'll make sure his back is covered if things turn bloody."
  }
]

base_time = DateTime.utc_now() |> DateTime.add(-300, :second)

for {{char, speech, thought}, idx} <- Enum.with_index(script) do
  if char do
    msg_time = DateTime.add(base_time, idx * 45, :second)

    %SceneMessage{}
    |> SceneMessage.changeset(%{
      scene_id: scene.id,
      character_id: char.id,
      message_type: "dialogue",
      content: speech,
      private_thought: thought,
      metadata: %{},
      inserted_at: msg_time
    })
    |> Repo.insert!()
  end
end

IO.puts("Seeded #{length(script)} dual-mind messages in #{scene.title}!")
