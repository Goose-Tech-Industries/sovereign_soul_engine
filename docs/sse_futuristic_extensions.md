# Sovereign Soul Engine — Futuristic Upgrades

This document outlines four high-impact architectural expansions to make the Sovereign Soul Engine (SSE) a industry-defining platform for artificial life.

---

## 1. The Dream Loop (Biological Memory Consolidation)

### Concept
Traditional AI chatbots keep an active transcript log that grows until it hits token limits and gets truncated. In SSE, we can model biological sleep to handle memory retention and decay.

### Implementation (Elixir OTP)
*   When an NPC's `NPCServer` process has been idle (no scene activity) for a configurable duration (e.g., 10 minutes in-game time), it enters `:dreaming` status.
*   The GenServer spawns an asynchronous background task (`Task.Supervisor`) to run the **Consolidation Cycle**:
    *   **Emotional Decay:** Linear or exponential decay is applied to temporary emotional residues (e.g., immediate anger drops by 15%, stress settles).
    *   **Episodic Distillation:** Recent chat logs and events are sent to a summarizing LLM call to extract semantic memories: *"What did I learn about this person? What events mattered?"*
    *   **Ledger Commit:** The distilled core memories are written to the database, and the raw conversation log is archived/pruned, keeping the active GenServer state extremely lightweight.

---

## 2. Epigenetic Belief Evolution

### Concept
Currently, an NPC's core values, fears, and desires are static strings in their `SoulProfile`. To make them feel human, their baseline identity must be mutable under extreme circumstances.

### Implementation
*   We introduce a `volatility` metric (0 to 100) to each core value and belief.
*   If an emotional `wound` exceeds 80 (e.g., a massive betrayal), or if `trust` remains at 100 for a long period (e.g., deep bonding), a **Belief Shift Event** is triggered:
    *   The `ConsequenceEngine` updates the `SoulProfile`.
    *   *Example:* An NPC with the core value `"Always protect the weak"` who suffers a severe betrayal may shift their value to `"Only protect those who prove their loyalty."`
    *   This shift is logged in the `SoulLedger` and modifies future prompt templates.

---

## 3. Social Gossip Propagation (Reputation Networks)

### Concept
If you betray an NPC in a room, the rest of the world shouldn't remain oblivious. NPCs should have a social network where they share memories.

### Implementation
*   NPCs can participate in **Background Scenes** (scenes with other NPCs, no players present).
*   During a background scene, the `SceneServer` prompts the participants to share high-importance memories involving common acquaintances.
*   *Example:* NPC A meets NPC B. A shares a memory: *"Goose betrayed me at the border."* 
*   NPC B’s `RelationshipEngine` processes this event. If B has high affinity for A, B's trust score toward Goose decrements by a fraction of A's trust loss:
    $$\Delta Trust_B = \Delta Trust_A \times Affinity(B \to A)$$
*   This propagates reputation throughout the game world autonomously.

---

## 4. Cognitive Load & Stress Biorhythms

### Concept
Stress and fear shouldn't just be numbers; they must change how the AI process thinks and makes decisions.

### Implementation
*   **Prompt Compression:** When `emotional_state.stress` is above 75, prompt templates are modified to restrict output length, forcing the LLM to output short, defensive, or erratic dialogue.
*   **Action Restriction:** Under extreme fear, the `ActionPolicy` automatically intercepts proposed complex actions (like "bargain" or "assist") and transforms them into "flee" or "freeze."
*   **Private Thought Fragmentation:** The private reasoning block in the JSON response is structured to be disorganized and hyper-focused on survival triggers.
