/**
 * Sovereign Soul Engine — JavaScript / TypeScript SDK
 * Connect web, Node.js, and Electron games to persistent artificial lives.
 */

class SovereignSoul {
  /**
   * @param {Object} options
   * @param {string} [options.baseUrl="http://localhost:8561"]
   * @param {string} [options.apiKey]
   */
  constructor({ baseUrl = "http://localhost:8561", apiKey = null } = {}) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.apiKey = apiKey;
  }

  _headers() {
    const headers = { "Content-Type": "application/json" };
    if (this.apiKey) {
      headers["Authorization"] = `Bearer ${this.apiKey}`;
    }
    return headers;
  }

  /**
   * Send dialogue to an NPC and receive speech, inner thoughts, and game actions.
   * @param {Object} params
   * @param {string} params.characterSlug
   * @param {string} params.message
   * @param {string} [params.sceneId]
   */
  async chat({ characterSlug, message, sceneId = null }) {
    const url = `${this.baseUrl}/sse/api/npc_chat`;
    const body = { character_slug: characterSlug, message };
    if (sceneId) body.scene_id = sceneId;

    const res = await fetch(url, {
      method: "POST",
      headers: this._headers(),
      body: JSON.stringify(body)
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SSE Error (${res.status}): ${errText}`);
    }

    const data = await res.json();
    return {
      publicSpeech: data.public_speech || "",
      privateThought: data.private_thought || "",
      tone: data.tone || "neutral",
      motivation: data.motivation || "",
      proposedAction: data.proposed_action || null,
      raw: data
    };
  }

  /**
   * Pulse player biometrics to NPCs.
   */
  async sendTelemetry({ playerSlug, heartRate, stressLevel, fatigueLevel = 15, motion = "resting" }) {
    const url = `${this.baseUrl}/sse/api/telemetry/somatic`;
    const res = await fetch(url, {
      method: "POST",
      headers: this._headers(),
      body: JSON.stringify({
        character_slug: playerSlug,
        heart_rate: heartRate,
        stress_level: stressLevel,
        fatigue_level: fatigueLevel,
        motion_state: motion
      })
    });
    return await res.json();
  }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { SovereignSoul };
}
