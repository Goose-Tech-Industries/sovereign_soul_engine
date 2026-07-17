import Ecto.Query

alias SovereignSoulEngine.Repo
alias SovereignSoulEngine.Characters.Character
alias SovereignSoulEngine.Souls.SoulProfile
alias SovereignSoulEngine.Souls.EmotionalState
alias SovereignSoulEngine.Beliefs.CharacterBelief
alias SovereignSoulEngine.Triggers.CharacterTrigger
alias SovereignSoulEngine.Desires.SoulDesire
alias SovereignSoulEngine.Secrets.CharacterSecret
alias SovereignSoulEngine.Souls.MoralLine
alias SovereignSoulEngine.Relationships.Relationship
alias SovereignSoulEngine.Scenes.Scene
alias SovereignSoulEngine.Scenes.SceneParticipant
alias SovereignSoulEngine.Souls.SomaticState
alias SovereignSoulEngine.Souls.GriefArc
alias SovereignSoulEngine.Souls.ForgivenessArc
alias SovereignSoulEngine.Goals.CharacterGoal
alias SovereignSoulEngine.TheoryOfMind.CharacterKnowledge

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
  version: 1,
  attachment_style: "avoidant",
  transference_profile: %{
    "when_reliable" =>
      "Reminds him of Sergeant Aldric — his mentor, who died because Vael wasn't there.",
    "when_unpredictable" => "Reminds him of Maren — the betrayer. He watches more carefully.",
    "when_vulnerable" => "Triggers protector instinct and simultaneous terror of being needed."
  },
  physical_tells: %{
    "anger" =>
      "His jaw muscles tighten. His right hand moves without thought toward his weapon hilt.",
    "fear" =>
      "His breathing slows and becomes deliberate — a trained response that looks like calm but isn't.",
    "sadness" => "His gaze drops slightly left. A long pause before he speaks.",
    "shame" => "He stops meeting your eyes. His voice flattens.",
    "stress" => "His thumb traces the old scar on his left forearm, back and forth."
  }
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

# ── Vael's Triggers ─────────────────────────────────────────

IO.puts("  Seeding Vael's triggers...")

vael_triggers = [
  %{
    character_id: vael.id,
    topic: "betrayal",
    reaction_type: "anger_spike",
    intensity_modifier: 35,
    flavor_text: "His posture stiffens. Something behind his eyes closes off."
  },
  %{
    character_id: vael.id,
    topic: "loyalty",
    reaction_type: "pride_surge",
    intensity_modifier: 20,
    flavor_text: "He pauses before responding — this word matters to him."
  },
  %{
    character_id: vael.id,
    topic: "family",
    reaction_type: "grief_spike",
    intensity_modifier: 25,
    flavor_text: "A long silence. His gaze moves to the middle distance."
  },
  %{
    character_id: vael.id,
    topic: "weakness",
    reaction_type: "anger_spike",
    intensity_modifier: 20,
    flavor_text:
      "His chin rises. He does not like this word applied to anyone, least of all himself."
  },
  %{
    character_id: vael.id,
    topic: "abandoned",
    reaction_type: "shame_trigger",
    intensity_modifier: 30,
    flavor_text: "Something flickers across his face and is immediately suppressed."
  },
  %{
    character_id: vael.id,
    topic: "protect",
    reaction_type: "pride_surge",
    intensity_modifier: 15,
    flavor_text: "He straightens almost imperceptibly."
  }
]

existing_trigger_topics =
  Repo.all(from t in CharacterTrigger, where: t.character_id == ^vael.id, select: t.topic)

Enum.each(vael_triggers, fn attrs ->
  unless attrs.topic in existing_trigger_topics do
    {:ok, _} = SovereignSoulEngine.Souls.create_trigger(attrs)
  end
end)

# ── Vael's Beliefs ───────────────────────────────────────────

IO.puts("  Seeding Vael's beliefs...")

vael_beliefs = [
  %{
    character_id: vael.id,
    belief: "Loyalty must be earned through repeated action, never assumed",
    domain: "social",
    conviction: 90
  },
  %{
    character_id: vael.id,
    belief: "Showing vulnerability invites exploitation",
    domain: "social",
    conviction: 85
  },
  %{
    character_id: vael.id,
    belief: "I am no longer fit to lead anyone",
    domain: "self",
    conviction: 60,
    is_challenged: false
  },
  %{
    character_id: vael.id,
    belief: "Strength is the only honest currency between people",
    domain: "world",
    conviction: 75
  },
  %{
    character_id: vael.id,
    belief: "The ambush was my failure — I was not where I should have been",
    domain: "self",
    conviction: 70
  }
]

existing_belief_texts =
  Repo.all(from b in CharacterBelief, where: b.character_id == ^vael.id, select: b.belief)

Enum.each(vael_beliefs, fn attrs ->
  unless attrs.belief in existing_belief_texts do
    {:ok, _} = SovereignSoulEngine.Souls.create_belief(attrs)
  end
end)

# ── Vael's Desires ───────────────────────────────────────────

IO.puts("  Seeding Vael's desires...")

vael_desires = [
  %{
    character_id: vael.id,
    desire: "Find and confront Maren, the soldier who sold us out",
    domain: "revenge",
    urgency: 80,
    status: "active"
  },
  %{
    character_id: vael.id,
    desire: "Prove — to himself more than anyone — that he can still be trusted to protect",
    domain: "redemption",
    urgency: 65,
    status: "active"
  },
  %{
    character_id: vael.id,
    desire: "Understand why Goose is actually here and what they want from him",
    domain: "knowledge",
    urgency: 55,
    status: "active"
  }
]

existing_desire_texts =
  Repo.all(from d in SoulDesire, where: d.character_id == ^vael.id, select: d.desire)

Enum.each(vael_desires, fn attrs ->
  unless attrs.desire in existing_desire_texts do
    {:ok, _} = SovereignSoulEngine.Souls.create_desire(attrs)
  end
end)

# ── Vael's Secrets ───────────────────────────────────────────

IO.puts("  Seeding Vael's secrets...")

vael_secrets = [
  %{
    character_id: vael.id,
    secret_text:
      "He survived the ambush because he had abandoned his post — he was 50 meters away getting water when they hit. He has told no one.",
    risk_level: "critical",
    domain: "self"
  },
  %{
    character_id: vael.id,
    secret_text: "He has been tracking Goose for three days before their first meeting.",
    risk_level: "medium",
    domain: "relationship"
  }
]

existing_secret_texts =
  Repo.all(from s in CharacterSecret, where: s.character_id == ^vael.id, select: s.secret_text)

Enum.each(vael_secrets, fn attrs ->
  unless attrs.secret_text in existing_secret_texts do
    {:ok, _} = SovereignSoulEngine.Souls.create_secret(attrs)
  end
end)

# ── Vael's Moral Lines ───────────────────────────────────────

IO.puts("  Seeding Vael's moral lines...")

vael_moral_lines = [
  %{
    character_id: vael.id,
    principle: "Will not harm anyone who cannot defend themselves",
    will_refuse_when_violated: true,
    action_types_blocked: ["attack"]
  },
  %{
    character_id: vael.id,
    principle: "Will not attack from behind or by ambush — he finds it obscene",
    will_refuse_when_violated: true,
    action_types_blocked: ["attack", "restrain"]
  },
  %{
    character_id: vael.id,
    principle: "Will not reveal a dying person's last words to their enemies",
    will_refuse_when_violated: true,
    action_types_blocked: []
  }
]

existing_principles =
  Repo.all(from m in MoralLine, where: m.character_id == ^vael.id, select: m.principle)

Enum.each(vael_moral_lines, fn attrs ->
  unless attrs.principle in existing_principles do
    {:ok, _} = SovereignSoulEngine.Souls.create_moral_line(attrs)
  end
end)

# ── Update Vael's Soul Profile with new fields ──────────────

IO.puts("  Updating Vael's soul profile with humor_style and emotional_susceptibility...")

vael_profile = Repo.get_by(SoulProfile, character_id: vael.id)
if vael_profile do
  SovereignSoulEngine.Souls.update_soul_profile(vael_profile, %{
    humor_style: "dark",
    emotional_susceptibility: 25
  })
end

# ── Vael's Somatic State ─────────────────────────────────────

IO.puts("  Seeding Vael's somatic state...")

unless Repo.get_by(SomaticState, character_id: vael.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_somatic_state(%{
    character_id: vael.id,
    hunger: 30,
    pain: 15,
    fatigue: 40,
    illness_severity: 0
  })
end

# ── Vael's Goals ─────────────────────────────────────────────

IO.puts("  Seeding Vael's goals...")

existing_vael_goals =
  Repo.all(from g in CharacterGoal, where: g.character_id == ^vael.id, select: g.goal)

vael_goals = [
  %{
    character_id: vael.id,
    goal: "Find and confront Maren before he disappears again",
    current_step: "Gathering information from travelers",
    blocker: nil,
    priority: 90,
    status: "active"
  },
  %{
    character_id: vael.id,
    goal: "Determine whether Goose can be trusted with the truth about the ambush",
    current_step: "Observing Goose's behavior in high-stakes moments",
    blocker: nil,
    priority: 70,
    status: "active"
  },
  %{
    character_id: vael.id,
    goal: "Rebuild enough to take on a protective role again",
    current_step: "Proving to himself he can still make the right call under pressure",
    blocker: "Deep self-doubt from the ambush — he does not believe he deserves the role yet",
    priority: 60,
    status: "active"
  }
]

Enum.each(vael_goals, fn attrs ->
  unless attrs.goal in existing_vael_goals do
    {:ok, _} = SovereignSoulEngine.Souls.create_goal(attrs)
  end
end)

# ── Vael's Grief Arcs ────────────────────────────────────────

IO.puts("  Seeding Vael's grief arcs...")

existing_vael_grief =
  Repo.all(from g in GriefArc, where: g.character_id == ^vael.id, select: g.subject)

vael_grief_arcs = [
  %{
    character_id: vael.id,
    subject: "Sergeant Aldric",
    loss_type: "person",
    stage: "depression",
    intensity: 65,
    triggered_at: DateTime.utc_now() |> DateTime.truncate(:second),
    is_resolved: false
  },
  %{
    character_id: vael.id,
    subject: "His role as guardian",
    loss_type: "role",
    stage: "bargaining",
    intensity: 50,
    triggered_at: DateTime.utc_now() |> DateTime.truncate(:second),
    is_resolved: false
  }
]

Enum.each(vael_grief_arcs, fn attrs ->
  unless attrs.subject in existing_vael_grief do
    {:ok, _} = SovereignSoulEngine.Souls.create_grief_arc(attrs)
  end
end)

# ── Vael's Forgiveness Arcs ──────────────────────────────────

IO.puts("  Seeding Vael's forgiveness arcs...")

existing_vael_forgiveness =
  Repo.all(from f in ForgivenessArc, where: f.character_id == ^vael.id, select: f.wound_description)

vael_forgiveness_arcs = [
  %{
    character_id: vael.id,
    wound_description: "Maren sold out the company for coin — men died because of his choice",
    stage: "festering",
    intensity: 85,
    direction: "hardening"
  },
  %{
    character_id: vael.id,
    wound_description: "He abandoned his post the night of the ambush — even if only briefly",
    stage: "processing",
    intensity: 70,
    direction: "healing"
  }
]

Enum.each(vael_forgiveness_arcs, fn attrs ->
  unless attrs.wound_description in existing_vael_forgiveness do
    {:ok, _} = SovereignSoulEngine.Souls.create_forgiveness_arc(attrs)
  end
end)

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

# ── Goose's Somatic State ────────────────────────────────────

IO.puts("  Seeding Goose's somatic state...")

unless Repo.get_by(SomaticState, character_id: goose.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_somatic_state(%{
    character_id: goose.id,
    hunger: 10,
    pain: 0,
    fatigue: 15,
    illness_severity: 0
  })
end

# ── Theory of Mind: Vael's beliefs about Goose ──────────────

IO.puts("  Seeding Theory of Mind entries...")

existing_knowledge =
  Repo.all(
    from k in CharacterKnowledge,
      where: k.knower_character_id == ^vael.id and k.subject_character_id == ^goose.id,
      select: k.known_fact
  )

vael_knowledge_of_goose = [
  %{
    knower_character_id: vael.id,
    subject_character_id: goose.id,
    known_fact: "Has been following the same road as Vael for three days — not accidental",
    certainty: 85,
    is_assumption: false,
    last_updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },
  %{
    knower_character_id: vael.id,
    subject_character_id: goose.id,
    known_fact: "Carries themselves like someone who has survived violence",
    certainty: 75,
    is_assumption: true,
    last_updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },
  %{
    knower_character_id: vael.id,
    subject_character_id: goose.id,
    known_fact: "Has not asked for anything directly — which means they want something specific",
    certainty: 70,
    is_assumption: true,
    last_updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }
]

Enum.each(vael_knowledge_of_goose, fn attrs ->
  unless attrs.known_fact in existing_knowledge do
    {:ok, _} = SovereignSoulEngine.TheoryOfMind.create_knowledge(attrs)
  end
end)

# ── New NPCs ─────────────────────────────────────────────────

IO.puts("  Creating Georgina (NPC)...")

georgina =
  case Repo.get_by(Character, slug: "georgina") do
    nil ->
      {:ok, char} = SovereignSoulEngine.Characters.create_character(%{
        name: "Georgina",
        slug: "georgina",
        kind: "npc",
        description: "A sharp-tongued tavern keeper who has seen everything and forgets nothing.",
        status: "active"
      })
      char
    char -> char
  end

unless Repo.get_by(SoulProfile, character_id: georgina.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_soul_profile(%{
    character_id: georgina.id,
    personality_traits: %{pragmatism: 85, warmth: 50, suspicion: 60, resilience: 90},
    core_values: ["Honesty above comfort", "Pay your debts", "Don't mistake kindness for weakness"],
    fears: ["Losing the tavern", "Becoming dependent on anyone"],
    desires: ["Quiet prosperity", "To see justice done to those who wronged her daughter"],
    speech_style: "Blunt, warm when earned, dry wit",
    behavioral_constraints: %{},
    baseline_emotions: %{anger: 10, fear: 5, stress: 25, gratitude: 15, confidence: 70, sadness: 20, curiosity: 40, attachment: 30},
    identity_summary: "Tavern keeper who has outlasted bandits, lords, and heartbreak. Runs the Blackthorn on her own terms.",
    attachment_style: "secure",
    humor_style: "dry",
    emotional_susceptibility: 35
  })
end

unless Repo.get_by(EmotionalState, character_id: georgina.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_emotional_state(%{
    character_id: georgina.id,
    anger: 10, fear: 5, stress: 25, gratitude: 15,
    confidence: 70, sadness: 20, curiosity: 40, attachment: 30
  })
end

unless Repo.get_by(SomaticState, character_id: georgina.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_somatic_state(%{
    character_id: georgina.id,
    hunger: 5, pain: 20, fatigue: 50, illness_severity: 0
  })
end

IO.puts("  Creating Codex (NPC)...")

codex =
  case Repo.get_by(Character, slug: "codex") do
    nil ->
      {:ok, char} = SovereignSoulEngine.Characters.create_character(%{
        name: "Codex",
        slug: "codex",
        kind: "npc",
        description: "An archivist of forgotten things who collects debts the way others collect coin.",
        status: "active"
      })
      char
    char -> char
  end

unless Repo.get_by(SoulProfile, character_id: codex.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_soul_profile(%{
    character_id: codex.id,
    personality_traits: %{intellect: 90, coldness: 65, patience: 80, obsession: 75},
    core_values: ["Knowledge is the only honest currency", "All debts must balance", "The past is always legible if you know how to read it"],
    fears: ["Information being destroyed", "Being forgotten", "Making an incorrect record"],
    desires: ["The complete history of the Maren betrayal", "To be owed by someone powerful"],
    speech_style: "Precise, detached, occasionally unsettling",
    behavioral_constraints: %{},
    baseline_emotions: %{anger: 5, fear: 15, stress: 20, gratitude: 5, confidence: 75, sadness: 10, curiosity: 90, attachment: 5},
    identity_summary: "Ancient archivist who trades in secrets and forgotten debts. Nothing escapes the ledger.",
    attachment_style: "avoidant",
    humor_style: "absurdist",
    emotional_susceptibility: 15
  })
end

unless Repo.get_by(EmotionalState, character_id: codex.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_emotional_state(%{
    character_id: codex.id,
    anger: 5, fear: 15, stress: 20, gratitude: 5,
    confidence: 75, sadness: 10, curiosity: 90, attachment: 5
  })
end

unless Repo.get_by(SomaticState, character_id: codex.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_somatic_state(%{
    character_id: codex.id,
    hunger: 0, pain: 0, fatigue: 10, illness_severity: 0
  })
end

IO.puts("  Creating Ecto Habien (NPC)...")

ecto_habien =
  case Repo.get_by(Character, slug: "ecto-habien") do
    nil ->
      {:ok, char} = SovereignSoulEngine.Characters.create_character(%{
        name: "Ecto Habien",
        slug: "ecto-habien",
        kind: "npc",
        description: "A disgraced mercenary captain who drinks to forget and fights to remember he exists.",
        status: "active"
      })
      char
    char -> char
  end

unless Repo.get_by(SoulProfile, character_id: ecto_habien.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_soul_profile(%{
    character_id: ecto_habien.id,
    personality_traits: %{aggression: 70, pride: 80, self_destruction: 55, loyalty: 75, shame: 65},
    core_values: ["A soldier keeps their word", "Strength earns the right to speak", "The dead deserve to be remembered honestly"],
    fears: ["Dying having never set things right", "Being pitied", "Trusting again and being wrong"],
    desires: ["One more contract worth taking", "Someone to tell the truth to", "To sleep without the faces"],
    speech_style: "Gruff, economical, explosive when cornered",
    behavioral_constraints: %{},
    baseline_emotions: %{anger: 35, fear: 20, stress: 45, gratitude: 10, confidence: 40, sadness: 50, curiosity: 20, attachment: 15},
    identity_summary: "Disgraced mercenary captain haunted by a betrayal he survived and a company he lost. Drinks hard and asks few questions.",
    attachment_style: "disorganized",
    humor_style: "dark",
    emotional_susceptibility: 60
  })
end

unless Repo.get_by(EmotionalState, character_id: ecto_habien.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_emotional_state(%{
    character_id: ecto_habien.id,
    anger: 35, fear: 20, stress: 45, gratitude: 10,
    confidence: 40, sadness: 50, curiosity: 20, attachment: 15
  })
end

unless Repo.get_by(SomaticState, character_id: ecto_habien.id) do
  {:ok, _} = SovereignSoulEngine.Souls.create_somatic_state(%{
    character_id: ecto_habien.id,
    hunger: 45, pain: 30, fatigue: 60, illness_severity: 10
  })
end

IO.puts("  Done seeding!")
IO.puts("")
IO.puts("  Vael ID: #{vael.id}")
IO.puts("  Goose ID: #{goose.id}")
IO.puts("  Scene ID: #{scene.id}")
