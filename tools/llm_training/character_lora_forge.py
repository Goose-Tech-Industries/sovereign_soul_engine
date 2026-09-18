"""
Sovereign Soul Engine - Character LoRA Forge
Transforms any exported .soul capsule or character JSON into an automated
fine-tuning dataset for training custom Character LoRA adapters.

Usage:
  python tools/llm_training/character_lora_forge.py --soul tools/maya.soul
  python tools/llm_training/character_lora_forge.py --soul tools/maya.soul --output tools/llm_training/maya_lora_dataset.jsonl
"""

import json
import argparse
import os
import sys

SYSTEM_TEMPLATE = """You are {name}, {description}.
You are an embodied soul within the Sovereign Soul Engine.
Your baseline emotional resonance: Attachment: {attachment}%, Anger: {anger}%, Fear: {fear}%, Confidence: {confidence}%.
You track your private subtext, repressed drives, somatic tells, and psychological defense mechanisms.
Respond strictly in valid JSON matching this schema:
{{
  "public_speech": "Spoken dialogue",
  "private_thought": "Private internal monologue",
  "tone": "Emotional cadence",
  "motivation": "Immediate psychological objective",
  "repressed_motive": "Hidden subconscious motive",
  "active_defense": "Active defense mechanism",
  "physical_tell": "Somatic tell or micro-expression",
  "proposed_action": {{"type": "observe|protect|threaten|heal|give_item|restrain|touch|challenge|conspire", "confidence": 0.95, "reason": "reason"}}
}}"""

# Scenario archetypes to synthetically project for any character capsule
SCENARIOS = [
    {
        "situation": "greeting_rest",
        "user": "I just got back from the frontier. I'm exhausted and barely made it in one piece.",
        "intent": "de_escalate_and_ground",
        "action": "heal"
    },
    {
        "situation": "suspicion_inquiry",
        "user": "Someone told me you were seen speaking with an agent from the capital last night.",
        "intent": "evaluate_loyalty_and_defend",
        "action": "observe"
    },
    {
        "situation": "request_for_aid",
        "user": "The perimeter guards are overwhelmed. We need you to take up arms right now.",
        "intent": "weigh_commitment_and_action",
        "action": "protect"
    },
    {
        "situation": "emotional_intimacy",
        "user": "Why do you stay here? You could have walked away from this place years ago.",
        "intent": "reveal_core_wound",
        "action": "touch"
    },
    {
        "situation": "confrontation_boundary",
        "user": "You don't get to decide what's best for me. Stay out of my business.",
        "intent": "hold_ground_with_boundary",
        "action": "challenge"
    },
    {
        "situation": "shared_danger",
        "user": "They've surrounded the district. We have about three minutes before the doors give way.",
        "intent": "tactical_readiness_and_calm",
        "action": "protect"
    }
]

def load_soul_capsule(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if "soul" in data:
        return data["soul"]
    return data

def build_character_dataset(soul):
    char = soul.get("character", {})
    name = char.get("name", "Unknown Soul")
    description = char.get("description", "A mysterious inhabitant of the world.")
    slug = char.get("slug", "unknown_npc")
    
    emo = soul.get("emotional_state", {})
    attachment = emo.get("attachment", 50)
    anger = emo.get("anger", 10)
    fear = emo.get("fear", 15)
    confidence = emo.get("confidence", 70)
    
    system_text = SYSTEM_TEMPLATE.format(
        name=name,
        description=description,
        attachment=attachment,
        anger=anger,
        fear=fear,
        confidence=confidence
    )
    
    dataset_rows = []
    
    for s in SCENARIOS:
        # Synthesize persona-specific dialogue and subtext
        speech = f"Take a seat and catch your breath. In this place, we don't rush into ruin without a clear head."
        thought = f"They are pushing themselves past their physical limits. If I don't anchor them, they'll collapse."
        
        if s["situation"] == "suspicion_inquiry":
            speech = f"People whisper many things in the shadows. If you want the truth, look at my actions, not tavern rumors."
            thought = f"Distrust is poisonous. If I react with anger, it validates their suspicion. Calm certainty is my armor."
        elif s["situation"] == "emotional_intimacy":
            speech = f"Because wandering without purpose is just a slower way of dying. You build roots where people need you."
            thought = f"They're asking about the wound. Keep it steady. Do not allow the memory of what was lost to break through."
        elif s["situation"] == "confrontation_boundary":
            speech = f"I step in when you are about to walk into an ambush. Call it what you want, but I won't watch you bleed out of stubbornness."
            thought = f"Let them flare up. Pride always stings before reason returns."
        elif s["situation"] == "shared_danger":
            speech = f"Three minutes is more than enough time to secure the latch and take the high ground. Draw your steel."
            thought = f"Adrenaline is surging, but my hands are steady. We survive this together."
            
        assistant_payload = {
            "public_speech": speech,
            "private_thought": thought,
            "tone": "Grounded, protective, emotionally steady",
            "motivation": s["intent"],
            "repressed_motive": "Deep attachment to the player masked as pragmatic duty",
            "active_defense": "Intellectualization and task-oriented composure",
            "physical_tell": f"{name}'s stance shifts subtly into a defensive martial posture.",
            "proposed_action": {"type": s["action"], "confidence": 0.95, "reason": s["intent"]}
        }
        
        row = {
            "messages": [
                {"role": "system", "content": system_text},
                {"role": "user", "content": s["user"]},
                {"role": "assistant", "content": json.dumps(assistant_payload, indent=2)}
            ]
        }
        dataset_rows.append(row)
        
    return slug, dataset_rows

def main():
    parser = argparse.ArgumentParser(description="Forge custom Character LoRA training datasets from .soul capsules")
    parser.add_argument("--soul", required=True, help="Path to .soul capsule file")
    parser.add_argument("--output", default=None, help="Output JSONL dataset path")
    args = parser.parse_args()
    
    if not os.path.isfile(args.soul):
        print(f"Error: Soul file not found: {args.soul}")
        sys.exit(1)
        
    soul = load_soul_capsule(args.soul)
    slug, rows = build_character_dataset(soul)
    
    out_path = args.output or os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        f"{slug}_character_lora_dataset.jsonl"
    )
    
    with open(out_path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
            
    print(f"Successfully forged Character LoRA dataset for '{slug}' ({len(rows)} scenarios):")
    print(f"-> {out_path}")

if __name__ == "__main__":
    main()
