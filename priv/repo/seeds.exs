import Ecto.Query

alias SovereignSoulEngine.Repo
alias SovereignSoulEngine.Characters.Character
alias SovereignSoulEngine.Souls.SoulProfile
alias SovereignSoulEngine.Souls.EmotionalState
alias SovereignSoulEngine.Relationships.Relationship
alias SovereignSoulEngine.Scenes.Scene
alias SovereignSoulEngine.Scenes.SceneParticipant

IO.puts("Seeding Sovereign Soul Engine data...")

# ── Vael (NPC) ──────────────────────────────────────────────

vael_attrs = %{
  name: "Vael",
  slug: "vael",
  kind: "npc",
  description: "A proud former guardian whose loyalty must be earned.",
  status: "active"
}

IO.puts("  Creating Vael (NPC)...")

vael =
  case Repo.get_by(Character, slug: "vael") do
    nil ->
      {:ok, char} = SovereignSoulEngine.Characters.create_character(vael_attrs)
      char

    char ->
      char
  end

vael_soul_attrs = %{
  character_id: vael.id,
  personality_traits: %{pride: 75, courage: 70, defensiveness: 65, loyalty: 80, cynicism: 55},
  core_values: [
    "Loyalty must be earned",
    "Strength is self-reliance",
    "Actions speak louder than words"
  ],
  fears: [
    "Depending on someone who will later betray him",
    "Being seen as weak",
    "Failing to protect"
  ],
  desires: ["To protect others without appearing vulnerable", "To find someone worthy of trust"],
  speech_style: "Controlled, blunt, defensive",
  behavioral_constraints: %{attachment_threshold: 60, trust_threshold: 40},
  baseline_emotions: %{
    anger: 15,
    fear: 10,
    stress: 20,
    gratitude: 5,
    confidence: 60,
    sadness: 10,
    curiosity: 30,
    attachment: 10
  },
  identity_summary:
    "Proud former guardian who protects others but fears betrayal. Loyalty must be earned.",
  version: 1
}

unless Repo.get_by(SoulProfile, character_id: vael.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_soul_profile(vael_soul_attrs)
end

vael_emotion_attrs = %{
  character_id: vael.id,
  anger: 15,
  fear: 10,
  stress: 20,
  gratitude: 5,
  confidence: 60,
  sadness: 10,
  curiosity: 30,
  attachment: 10
}

unless Repo.get_by(EmotionalState, character_id: vael.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_emotional_state(vael_emotion_attrs)
end

# ── Goose (Player) ──────────────────────────────────────────

goose_attrs = %{
  name: "Goose",
  slug: "goose",
  kind: "player",
  description: "Unpredictable ally whose motives are hard to read.",
  status: "active"
}

IO.puts("  Creating Goose (Player)...")

goose =
  case Repo.get_by(Character, slug: "goose") do
    nil ->
      {:ok, char} = SovereignSoulEngine.Characters.create_character(goose_attrs)
      char

    char ->
      char
  end

goose_soul_attrs = %{
  character_id: goose.id,
  personality_traits: %{
    unpredictability: 70,
    charisma: 60,
    cunning: 55,
    bravery: 50,
    compassion: 45
  },
  core_values: ["Freedom above all", "Never show your full hand"],
  fears: ["Being predictable", "Losing autonomy"],
  desires: ["To prove loyalty on own terms", "To be understood without explaining"],
  speech_style: "Casual, cryptic, occasionally warm",
  behavioral_constraints: %{},
  baseline_emotions: %{
    anger: 5,
    fear: 5,
    stress: 10,
    gratitude: 10,
    confidence: 70,
    sadness: 5,
    curiosity: 60,
    attachment: 15
  },
  identity_summary: "Unpredictable ally who acts on impulse but means well.",
  version: 1
}

unless Repo.get_by(SoulProfile, character_id: goose.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_soul_profile(goose_soul_attrs)
end

goose_emotion_attrs = %{
  character_id: goose.id,
  anger: 5,
  fear: 5,
  stress: 10,
  gratitude: 10,
  confidence: 70,
  sadness: 5,
  curiosity: 60,
  attachment: 15
}

unless Repo.get_by(EmotionalState, character_id: goose.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_emotional_state(goose_emotion_attrs)
end

# ── Vael -> Goose Relationship ──────────────────────────────

rel_attrs = %{
  source_character_id: vael.id,
  target_character_id: goose.id,
  affinity: 10,
  trust: 25,
  respect: 45,
  fear: 5,
  anger: 20,
  gratitude: 10,
  debt: 0,
  softening: 15,
  hardening: 35,
  wound: 20
}

unless Repo.get_by(Relationship, source_character_id: vael.id, target_character_id: goose.id) do
  {:ok, _} = SovereignSoulEngine.Relationships.create_relationship(rel_attrs)
end

# ── Default Scene ───────────────────────────────────────────

scene_attrs = %{
  title: "Testing Grounds",
  status: "active",
  location: "The Hollow Bastion",
  context: %{mood: "tense", weather: "overcast"},
  started_at: DateTime.utc_now()
}

IO.puts("  Creating Default Scene...")

scene =
  case Repo.one(from s in Scene, where: s.title == "Testing Grounds", limit: 1) do
    nil ->
      {:ok, scene} = SovereignSoulEngine.Scenes.create_scene(scene_attrs)
      scene

    scene ->
      scene
  end

# Add participants
for char_id <- [vael.id, goose.id] do
  existing =
    Repo.one(
      from p in SceneParticipant,
        where: p.scene_id == ^scene.id and p.character_id == ^char_id
    )

  unless existing do
    SovereignSoulEngine.Scenes.add_participant(%{
      scene_id: scene.id,
      character_id: char_id
    })
  end
end

IO.puts("  Done seeding!")
IO.puts("")
IO.puts("  Vael ID: #{vael.id}")
IO.puts("  Goose ID: #{goose.id}")
IO.puts("  Scene ID: #{scene.id}")
