"""
Sovereign Soul Engine — Python SDK
Drop-in client to connect Unity, Godot, Pygame, or custom RPG backends to persistent NPC souls.
"""

from dataclasses import dataclass, field
from typing import Optional, Dict, Any, List
import urllib.request
import json
import urllib.error

@dataclass
class SoulAction:
    type: str
    confidence: float
    reason: str

@dataclass
class SoulResponse:
    public_speech: str
    private_thought: str
    tone: str
    motivation: str
    proposed_action: Optional[SoulAction] = None
    raw: Dict[str, Any] = field(default_factory=dict)

class SovereignSoul:
    """Client for connecting game loops and servers to Sovereign Soul Engine."""

    def __init__(self, base_url: str = "http://localhost:8561", api_key: Optional[str] = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    def _headers(self) -> Dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return headers

    def chat(self, character_slug: str, message: str, scene_id: Optional[str] = None) -> SoulResponse:
        """Send player dialogue to an NPC and receive simulated speech, private thoughts, and proposed game actions."""
        url = f"{self.base_url}/sse/api/npc_chat"
        payload = {
            "character_slug": character_slug,
            "message": message
        }
        if scene_id:
            payload["scene_id"] = scene_id

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(),
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=10.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            err_msg = e.read().decode("utf-8")
            raise RuntimeError(f"SSE Error ({e.code}): {err_msg}")

        action_data = data.get("proposed_action") or {}
        action = None
        if action_data:
            action = SoulAction(
                type=action_data.get("type", "none"),
                confidence=float(action_data.get("confidence", 0.0)),
                reason=action_data.get("reason", "")
            )

        return SoulResponse(
            public_speech=data.get("public_speech", ""),
            private_thought=data.get("private_thought", ""),
            tone=data.get("tone", "neutral"),
            motivation=data.get("motivation", ""),
            proposed_action=action,
            raw=data
        )

    def send_telemetry(self, player_slug: str, heart_rate: int, stress_level: int, fatigue_level: int = 15, motion: str = "resting") -> Dict[str, Any]:
        """Pulse player smartwatch telemetry into all surrounding NPCs' Theory of Mind."""
        url = f"{self.base_url}/sse/api/telemetry/somatic"
        payload = {
            "character_slug": player_slug,
            "heart_rate": heart_rate,
            "stress_level": stress_level,
            "fatigue_level": fatigue_level,
            "motion_state": motion
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(),
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=5.0) as resp:
            return json.loads(resp.read().decode("utf-8"))
