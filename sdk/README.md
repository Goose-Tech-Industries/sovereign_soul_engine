# Sovereign Soul Engine — Headless Game SDK

Lightweight, zero-dependency client SDKs to plug living NPC souls into your games in 5 lines of code.

---

## 🐍 Python (Pygame, Arcade, Custom Engines)

```python
from sovereign_soul import SovereignSoul

# Initialize client
soul = SovereignSoul(base_url="http://localhost:8561")

# Chat with an NPC
reply = soul.chat(character_slug="vael", message="Did you hide the key in the old cathedral?")

print("Spoken Dialogue:", reply.public_speech)
print("Secret Motive:  ", reply.private_thought)
print("Proposed Action:", reply.proposed_action.type) # e.g. "draw_weapon", "bargain", "evaluate_loyalty"
```

---

## 🌐 JavaScript / TypeScript (Node.js, Electron, Web Games)

```javascript
const { SovereignSoul } = require('./sovereign_soul');

const soul = new SovereignSoul({ baseUrl: 'http://localhost:8561' });

async function talk() {
  const reply = await soul.chat({
    characterSlug: 'maya',
    message: 'We are leaving at midnight.'
  });
  
  console.log(reply.publicSpeech);
  console.log(reply.privateThought);
}
talk();
```

---

## 🎮 Godot 4 (GDScript)

Add `SovereignSoulClient.gd` to your Godot scene tree:

```gdscript
extends Node2D

@onready var soul = $SovereignSoulClient

func _ready():
    soul.response_received.connect(_on_soul_response)
    soul.chat("ravina", "I know who betrayed you.")

func _on_soul_response(speech: String, thought: String, action: Dictionary):
    print("Spoken: ", speech)
    print("Private thought: ", thought)
```
