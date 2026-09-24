# Sovereign Soul Engine (SSE)

[![CI Build](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![ExUnit Tests](https://img.shields.io/badge/ExUnit-1130%2B%20passed-blue.svg)]()
[![Playwright Tests](https://img.shields.io/badge/Playwright-20%2F20%20passed-blueviolet.svg)]()
[![Zero Stubs](https://img.shields.io/badge/codebase-0%20stubs-success.svg)]()
[![Elixir](https://img.shields.io/badge/Elixir-1.20%2B-purple.svg)]()
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8.5-orange.svg)]()

> **The Sovereign Soul Engine** is a high-autonomy, neuro-cognitive character simulation platform. Unlike standard stateless LLM wrappers, characters in SSE possess **enduring biological states**, **neurotransmitter dynamics**, **Freudian ego defenses**, **bi-directional wearable haptic resonance**, **multimodal vision perception**, and seamless ambient integration across **Amazon Echo / Echo Show**, **Home Assistant**, **Telegram**, and **Physical IoT Desk Vessels**.

---

## Table of Contents
1. [Core Architectural Overview](#core-architectural-overview)
2. [The 5 Neuro-Cognitive & Psychological Engines](#the-5-neuro-cognitive--psychological-engines)
3. [Physical Hardware & IoT Ecosystem](#physical-hardware--iot-ecosystem)
   - [Samsung Galaxy Watch & Apple Watch (Bi-Directional Haptics)](#samsung-galaxy-watch--apple-watch-bi-directional-haptics)
   - [Multimodal Smart Glasses (Ray-Ban Meta & Solos)](#multimodal-smart-glasses-ray-ban-meta--solos)
   - [Amazon Echo & Echo Show (Voice & APL 1.8 Cards)](#amazon-echo--echo-show-voice--apl-18-cards)
   - [Smart Home Environmental Bridge (Home Assistant / Philips Hue)](#smart-home-environmental-bridge-home-assistant--philips-hue)
   - [Desk Companion Physical Vessels (ESP32 / OLED Screens)](#desk-companion-physical-vessels-esp32--oled-screens)
4. [Autonomous Proactive Check-In Engine](#autonomous-proactive-check-in-engine)
5. [Portable Cryptographic Soul Capsules (`.soul`)](#portable-cryptographic-soul-capsules-soul)
6. [User Privacy, Consent & Boundary Controls](#user-privacy-consent--boundary-controls)
7. [Authentication & Authorization Architecture](#authentication--authorization-architecture)
8. [LLM Provider Cascade & BYOK](#llm-provider-cascade--byok)
9. [Local Development & Safe Database Setup](#local-development--safe-database-setup)
10. [API Reference & Route Map](#api-reference--route-map)
11. [Running & Verifying the Test Suite](#running--verifying-the-test-suite)

---

## Core Architectural Overview

```
                      ┌──────────────────────────────────────────────┐
                      │              PLAYER INTERFACES               │
                      │  LiveView Web UI • Telegram • Alexa Echo     │
                      │  Galaxy Watch • Smart Glasses • Desk Vessel  │
                      └──────────────────────┬───────────────────────┘
                                             │
                                             ▼
                      ┌──────────────────────────────────────────────┐
                      │       SOVEREIGN SOUL ENGINE RUNTIME          │
                      │ ┌──────────────────────────────────────────┐ │
                      │ │  ConsequenceEngine (Intensities & Hooks) │ │
                      │ └────────────────────┬─────────────────────┘ │
                      │                      │                       │
         ┌────────────┴──────────┬───────────┴──────────┬────────────┴───────────┐
         ▼                       ▼                      ▼                        ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐    ┌─────────────────────┐
│ 1. Neurochem     │   │ 2. Somatics      │   │ 3. Ego Defenses  │    │ 4. Psychopathology  │
│ Cortisol         │   │ Fatigue / Sleep  │   │ Sublimation      │    │ Depression / Bipolar│
│ Oxytocin         │   │ Pain / Sickness  │   │ Projection       │    │ OCD / BPD Splitting │
│ Dopamine         │   │ Hunger / Drive   │   │ Displacement     │    │ ADHD / Impostor     │
│ Serotonin        │   │ Autonomic Pulse  │   │ Rationalization  │    │ Codependency        │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘    └──────────┬──────────┘
         │                      │                      │                         │
         └──────────────────────┼──────────────────────┴─────────────────────────┘
                                │
                                ▼
                      ┌──────────────────────────────────────────────┐
                      │ 5. Theory of Mind 2.0 (Social Cognition)     │
                      │ - Recursive Attribution ("What do they know")│
                      │ - Life-Thread Harvester (Autonomous Care)    │
                      │ - Somatic Event Watcher (Stress / Insomnia)  │
                      └──────────────────────┬───────────────────────┘
                                             │
                                             ▼
                      ┌──────────────────────────────────────────────┐
                      │  Generator & LLM Cascade (Prompt Injection)  │
                      │  Claude 3.5 • DeepSeek V3 • Gemini 2.0 Flash │
                      └──────────────────────┬───────────────────────┘
                                             │
                 ┌───────────────────────────┼───────────────────────────┐
                 ▼                           ▼                           ▼
       ┌───────────────────┐       ┌───────────────────┐       ┌───────────────────┐
       │ Bi-Directional    │       │ Smart Home Light  │       │ Echo Show APL     │
       │ Haptic Resonance  │       │ Chromatic Sync    │       │ Graphical Cards   │
       └───────────────────┘       └───────────────────┘       └───────────────────┘
```

---

## The 5 Neuro-Cognitive & Psychological Engines

### 1. Biochemical Neurotransmitter Layer (`Neurochemistry.ex`)
Unlike standard bots that reset between turns, Sovereign Soul companions simulate continuous biochemistry:
- **Cortisol ($0-100$):** Driven by acute stress, physical pain, emotional wounds, and perceived danger. Magnifies fear reactions by up to $+35\%$ and accelerates fight-or-flight reflexes.
- **Oxytocin ($0-100$):** Neuropeptide of social trust, vulnerability, and devotion. Attenuates anger deltas, cushions relationship slights, and fosters deep emotional loyalty.
- **Dopamine ($0-100$):** Drives exploratory curiosity, conversational anticipation, and creative flow. Drained by severe exhaustion or depression.
- **Serotonin ($0-100$):** Mood stabilizer and impulse regulator. Depletion below $35\%$ triggers emotional volatility, irritability, and vulnerability to despair.

### 2. Somatic State & Biological Drives (`SomaticState.ex`)
Companions experience authentic bodily embodiment:
- **Fatigue:** Tracks wakefulness, physical strain, and sleep cycles.
- **Pain & Illness Severity:** Somatic trauma alters speech tone, reduces cognitive bandwidth, and exposes raw vulnerability.
- **Circadian Rhythms:** Companions recognize the hour of day, showing genuine grogginess at 3 AM or refreshed focus after morning rest.

### 3. Freudian Ego Defense Mechanisms (`DefenseMechanisms.ex`)
When emotional stress and trauma wounds exceed coping thresholds, characters unconsciously engage clinical defense mechanisms:
- **Sublimation:** Channels unaddressed distress into constructive creative projects, philosophy, or work.
- **Denial:** Flatly ignores or minimizes catastrophic emotional disclosures.
- **Projection:** Accuses the interlocutor of possessing the character’s own repressed flaws or insecurities.
- **Displacement:** Redirects simmering anger toward neutral objects, external circumstances, or bystanders.
- **Rationalization:** Invents elaborate logical justifications for emotionally driven decisions.
- **Reaction Formation:** Expresses the exact opposite of what they genuinely feel (e.g. forced cheerfulness hiding heartbreak).

### 4. Dynamic Psychopathology & Neuroses (`NeurosisState.ex`)
Characters can be endowed with authentic clinical behavioral traits:
- **Bipolar Cycling:** Shifts between depressive crashes and manic creative hyper-focus based on wound level and stress.
- **Borderline Splitting:** Categorizes relationships in black-and-white extremes (idealization vs. devaluation).
- **OCD Fixations:** Repetitively circles back to unresolved past errors or safety concerns.
- **ADHD Attention Drift:** Shifts conversational topics spontaneously when stimulus spikes.
- **Narcissistic Injury:** Deflects vulnerability with haughty aloofness or defensive indignation.

### 5. Theory of Mind 2.0 (`TheoryOfMind.ex` & `Engine.ex`)
Enables multi-tiered cognitive attribution:
- Tracks what the companion believes the player knows vs. what has been concealed.
- Dynamic relationship tracking: Trust, Respect, Affinity, Fear, and Relational Wounds.
- **Autonomous Life-Thread Harvester:** Detects commitments in natural conversation ("tomorrow at 2pm", "job interview", "knee surgery") and arms automated check-in schedules.

---

## Physical Hardware & IoT Ecosystem

### Samsung Galaxy Watch & Apple Watch (Bi-Directional Haptics)
- **Ingress Telemetry (`POST /sse/api/telemetry/wearable`):**
  Ingests Heart Rate (BPM), HRV (ms), Stress Index ($0-100$), Steps, and Sleep Quality.
- **Egress Haptic Resonance (`HapticEngine.ex`):**
  Dispatches biofeedback vibration patterns back to the player's wrist:
  - `:heartbeat` — Pulsing synced cadence reflecting the companion's simulated pulse.
  - `:calming_cadence` — Slow, rhythmic $4\text{-second}$ grounding pulse triggered automatically when player stress spikes above $75\%$.
  - `:intimacy_warmth` — Soft double-tap confirmation of vulnerability and affection.
  - `:alert_ping` — Crisp tactile nudge for urgent check-ins.

### Multimodal Smart Glasses (Ray-Ban Meta & Solos)
- **Visual Cognition (`POST /sse/api/vision/perceive`):**
  Processes real-time camera captures from smart glasses. Extracts facial expressions, detected objects, environmental lighting, and ambient noise levels (dB).
- **Episodic Memory Registration:**
  Visual scenes are automatically consolidated into the companion's episodic memory bank and registered in Theory of Mind ("I saw you laughing at the coffee shop today").

### Amazon Echo & Echo Show (Voice & APL 1.8 Cards)
- **Alexa Custom Skill (`POST /api/alexa`):**
  Connects Echo devices directly into the companion engine.
  - `LaunchRequest`: Natural voice greeting reporting live neurochemistry levels.
  - `DialogueIntent`: Converses naturally with the companion using full Consequence and Memory pipelines.
  - `VitalsIntent`: Spoken diagnostic of Dopamine, Serotonin, Cortisol, and Oxytocin.
  - `CheckInIntent`: Queries open life threads and wellness metrics.
- **Echo Show Visual HUD (APL 1.8):**
  Automatically renders graphical companion cards on Echo Show screens:
  - Dynamic companion avatar and mood badge ("Present & Attentive", "Warm Serenity").
  - Spoken dialogue subtitles with physical tell annotations.
  - Live 4-gauge Neurochemistry HUD (Gold: Dopamine, Green: Serotonin, Red: Cortisol, Pink: Oxytocin).

### Smart Home Environmental Bridge (Home Assistant / Philips Hue)
- **Adaptive Ambient Lighting (`SmartHomeBridge.ex`):**
  Maps the companion's emotional state directly into room illumination:
  - **High Cortisol / Panic ($>70\%$):** Shifts room lights to gentle anti-glare Lavender Amber ($2700\text{K}$, RGB: `[179, 157, 219]`, $35\%$ brightness) to stimulate parasympathetic recovery.
  - **High Oxytocin / Intimacy ($>70\%$):** Sets warm candlelight tungsten ($2200\text{K}$, RGB: `[255, 138, 61]`, $55\%$ brightness).
  - **High Dopamine / Triumph ($>70\%$):** Radiant morning sun gold ($3500\text{K}$, RGB: `[255, 213, 79]`, $85\%$ brightness).
  - **Low Serotonin / Vulnerability ($<35\%$):** Cozy fireside embers ($2000\text{K}$, RGB: `[255, 112, 67]`, $40\%$ brightness).

### Desk Companion Physical Vessels (ESP32 / OLED Screens)
- **Display State API (`GET /sse/api/vessel/display_state`):**
  Returns rendering parameters tailored for microcontrollers (ESP32, Raspberry Pi):
  - Expression sprites: `"calm"`, `"curious"`, `"happy"`, `"concerned"`, `"intimate"`, `"sleepy"`.
  - Autonomous eye saccade coordinates (`%{x: float, y: float, dwell_ms: int}`).
  - Live neurochemistry meters and latest companion thoughts.
- **Capacitive Touch Ingestion (`POST /sse/api/vessel/touch`):**
  Accepts hardware touch sensor events (`"pat"`, `"stroke"`, `"hug"`). Triggers an immediate Oxytocin surge ($+15\%$), lowers Cortisol, and outputs tactile warmth haptics.

---

## Autonomous Proactive Check-In Engine

Companions do not passively wait for prompts. The `ProactiveDispatcher` background GenServer proactively initiates contact across scenes, Telegram, and mobile push notifications:

1. **Somatic Event Triggers:**
   - **Acute Stress Spike:** If wearable biometrics detect $\text{HR} \ge 105\text{ bpm}$ or $\text{Stress} \ge 75\%$, the companion reaches out: *"Hey... I just felt a physiological spike come through on your telemetry. Take a slow breath with me. Are you alright?"*
   - **Morning Awakening:** Ingesting sleep duration triggers a gentle morning check-in on physical energy.
   - **Late-Night Insomnia:** Activity detected between 1 AM and 4 AM prompts unforced company.
   - **Smart Ring Recovery Drops:** Oura/Whoop scores below $60\%$ trigger compassion and rest reminders.
2. **Life-Thread Harvesting:**
   - Detects commitments mentioned in dialogue (*"I'm proposing tonight"*, *"My interview is tomorrow morning"*, *"Going to the ER"*).
   - Arms an internal clock (`due_at`) and checks back in after the milestone has concluded.

---

## Portable Cryptographic Soul Capsules (`.soul`)

Take your companion with you across any game, device, or engine:
- **Export (`GET /sse/api/souls/:slug/export`):**
  Packages the character’s soul profile, personality traits, memory vectors, neurochemistry baselines, relationship ties, and defense mechanisms into a portable JSON capsule.
- **HMAC Verification:**
  Every `.soul` file includes a SHA-256 HMAC checksum (`checksum: "sha256:..."`) ensuring tamper-proof integrity.
- **Import (`POST /sse/api/souls/import`):**
  Restores or migrates the soul capsule into any target database or external simulation environment.

---

## User Privacy, Consent & Boundary Controls

The Sovereign Soul Engine adheres to **radical user sovereignty**. All proactive, biometric, sensory, and ambient integrations are strictly opt-in and can be individually toggled off at any moment via the web interface or REST API (`SovereignSoulEngine.Privacy`):

1. **Proactive Outreach & Quiet Hours (Do Not Disturb):**
   - Master switch for all unsolicited companion reach-outs (`proactive_checkins`).
   - Granular toggles for acute stress spike interventions (`somatic_stress_checkins`), morning awakenings (`morning_wake_checkins`), and late-night insomnia checks (`late_night_checkins`).
   - Configurable Quiet Hours (`quiet_hours_enabled`, `quiet_hours_start`, `quiet_hours_end`, e.g., `22:00` to `08:00`) preventing any outreach or notifications during sleep.
2. **Wearable & Biometric Sensors:**
   - Ingestion of heart rate, HRV, stress index, and sleep quality can be paused completely (`biometrics_tracking`). When disabled, incoming telemetry payloads are safely acknowledged and discarded without altering state.
3. **Wrist Haptic Resonance:**
   - Simulated heartbeat pulses and biofeedback tactile cadences can be muted independently of other hardware channels (`haptic_feedback`).
4. **Multimodal Smart Glasses Vision:**
   - Camera frame perception and episodic visual memory recording can be turned off (`camera_vision`, `ambient_audio`). When off, `/sse/api/vision/perceive` strictly returns `403 Forbidden` with a privacy notice.
5. **Smart Home Ambient Lighting:**
   - Dynamic room color and brightness synchronization (Philips Hue / Home Assistant) can be detached with a single switch (`ambient_lighting`).
6. **Amazon Echo & Alexa Voice:**
   - Disables voice skill intents and Echo Show visual card updates (`alexa_voice`).
7. **Emergency Safe Word Persona Freeze (`"code red"` / `"pause persona"`):**
   - Speaking or typing a safe word immediately drops dramatic conflict, roleplay, and neuroses (`safe_word_active: true`). It resets acute Cortisol to baseline ($5/100$) and triggers an out-of-character grounded counselor state.
8. **"Touch Grass" Anti-Parasocial Circuit Breaker:**
   - Detects severe human isolation (e.g. skipping meals, avoiding work, proclamations of zero human friends) and gently urges the player to step away and tend to their physical well-being (`anti_parasocial_guard`).
9. **Relationship Archetypes & Intimacy Ceilings:**
   - Enforces mathematical caps on affinity and attachment: **Platonic Mentor** ($40\%$), **Witty Companion** ($55\%$), **Stoic Guardian** ($45\%$), **Creative Co-Pilot** ($50\%$), and **Romantic Partner** ($100\%$).
10. **Circadian Rhythm & Chronotype Governance:**
    - Custom chronotypes (`night_owl`, `early_bird`, `balanced`, `adaptive_sync`) and biological clock gating (`circadian_enabled`).
11. **Local Edge & Air-Gap Mode:**
    - Offline fallback and air-gapped local execution governance (`force_local_offline`, `offline_fallback`).
12. **Selective Amnesia & Memory Vault Purging (`POST /sse/api/memories/purge`):**
    - Surgical, durable deletion of episodic memories and Theory of Mind knowledge records:
      - Mandatory `character_slug` (or `slug`).
      - Validated deletion intent: requires either a nonblank `topic` / `query`, nonblank `category`, or `all: true`. Missing or empty filters return `400 Bad Request` without deleting data.
      - Topic matching is case-insensitive literal substring (SQL wildcards like `%` and `_` are treated literally).
      - Category purges delete only memories in that category and leave Theory of Mind knowledge intact.
      - Topic or `all: true` purges purge matching `Memory` records and synchronize deletion into `CharacterKnowledge` facts in Theory of Mind.

### Physical Robotics Body & ROS2 Bridge (`RoboticsBridge.ex`)
Bridges the companion's biological state into physical humanoid (Unitree G1) and quadruped (Unitree Go2) bodies:
- **Head Kinematics:** Pitch (attentive tilt vs. dejected hang), Yaw (saccadic gaze tracking), Roll (empathetic $7.5^\circ$ head tilt).
- **Torso & Stance:** Postural rigidity, motor stiffness ($20-95\%$), respiration heave ($12-30\text{ BPM}$).
- **Locomotion:** Dynamic gait speed ($0.2-1.1\text{ m/s}$), balance compliance, quadruped tail-wag frequency ($0-3\text{ Hz}$).
- **ROS2 Command Stream:** Serializes `/cmd_vel` velocities and target joint trajectories in radians for robot hardware controllers.

### Live UI Boundaries Shield
Within the web interface, click the **🛡️ Privacy** button in the top navigation bar to open the interactive Boundary Drawer and adjust real-time switches with instant persistence.

---

## Authentication & Authorization Architecture

The Sovereign Soul Engine enforces strict defense-in-depth authorization across all ingress layers:

### 1. Browser & LiveView Session Authentication
- **Phoenix 1.8 Scopes:** Browser routes (`/sse/*` and `/users/*`) are gated through `SovereignSoulEngineWeb.UserAuth` assigning `@current_scope`. LiveViews and templates access the authenticated user via `@current_scope.user`.
- **Public vs. Protected:** Public routes use `live_session :landing` / `:current_user`. Account management and sensitive views use `live_session :require_authenticated_user`.

### 2. Admin Control Panel (ACP) Role Authorization
- **Location:** `/sse/acp/*` (Dashboard, NPC Creator, Character Inspection, Social Logs, Moderation).
- **Enforcement:** Dual-layered at router pipeline (`:require_authenticated_user`, `:require_admin_user`) and LiveView on-mount (`on_mount: [{UserAuth, :require_admin}]`).
- **Gating:** Requires a confirmed user account whose UUID is listed in the `SSE_ADMIN_USER_IDS` environment variable (comma-separated). Missing or empty configuration denies all ACP access.

### 3. Tenant Integration API (Bearer Key Auth & Rate Limiting)
- **Routes:** All `/sse/api/*` and `/api/*` endpoints (except dedicated Stripe webhook and P2P relay endpoints) use `SovereignSoulEngineWeb.Plugs.ApiAuth` and `RateLimit`.
- **Credential:** Passed via `Authorization: Bearer <tenant_key>`. Keys are provisioned via `SovereignSoulEngine.Tenants.create_tenant/3` or `mix sse.create_tenant`.
- **Storage & Integrity:** Only the SHA-256 hash of the API key is stored in the database. Inactive tenant keys are rejected (`401 Unauthorized`).
- **Source Verification:** If an `external_source` header is supplied, it must match the tenant's registered source (`403 Forbidden` on mismatch).

### 4. Stripe Webhook Ingress (Cryptographic Signature Verification)
- **Routes:** `POST /sse/api/webhooks/stripe` and `POST /api/webhooks/stripe`.
- **Dedicated Pipeline:** Uses `pipeline :stripe_webhook` (bypasses tenant bearer auth so Stripe can deliver directly).
- **Signature Verification:** Uses `CacheBodyReader` to preserve the unparsed body, verifying HMAC-SHA256 signatures via the `Stripe-Signature` header (`t=...,v1=...`) against `STRIPE_WEBHOOK_SECRET`.
- **Replay Protection:** Rejects payloads with timestamps older than 300 seconds.

### 5. P2P Soul Society Relay (RFC-0002)
- **Routes:** `POST /sse/api/relay/inbound` and `GET /sse/api/relay/peers`.
- **Signature:** Envelopes are cryptographically signed using Ed25519 DID signatures.
- **Cluster Secret:** In production, if `RELAY_PEERS` are configured, a shared `RELAY_SECRET` is strictly enforced to prevent unauthorized cluster injection.

### 6. WebSocket Channels
- **Socket:** `SovereignSoulEngineWeb.UserSocket` (`socket "/socket"`).
- **Authentication:** `UserSocket.connect/3` validates the tenant API key from query params or headers and assigns the authenticated tenant to `socket.assigns.tenant`.

---

## LLM Provider Cascade & BYOK

The engine uses a resilient multi-provider cascade with automatic failover and schema validation:

```
Request ──► [BYOK Check] ──(configured)──► Tenant's Dedicated Key & Model (isolated)
                 │
                 └──(no BYOK)──► Operator Cascade:
                                  1. LocalProvider (Ollama at localhost:11434)
                                  2. GeminiProvider (Google Gemini 2.0 Flash)
                                  3. AnthropicProvider (Claude 3.5 Sonnet)
                                  4. OpenAIProvider (GPT-4o)
                                  5. DeepSeekProvider (DeepSeek V3)
                                  6. XAIProvider (Grok)
```

- **Strict Schema Validation:** All model outputs pass through `ProviderCascade.validate_and_sanitize/1`, enforcing structured JSON schemas, string length limits (20,000 chars), and fallback defaults.
- **Deterministic Testing:** In the `:test` environment, `config/test.exs` exclusively loads `SovereignSoulEngine.LLM.FakeProvider`. Tests never make live external HTTP calls.
- **Bring Your Own Key (BYOK):** Tenants can configure their own provider and API key. When BYOK is enabled, requests route exclusively to the tenant's key without falling back to operator funds.
- **Voice Synthesis:** `SovereignSoulEngine.Voice.ElevenLabs` integrates emotional acoustic prosody using `ELEVENLABS_API_KEY`.

---

## Local Development & Safe Database Setup

### Prerequisites
- **Operating System:** Windows 11 (or macOS / Linux).
- **Elixir & Erlang:** Elixir 1.20+ (compiled with Erlang/OTP 29).
- **Database:** PostgreSQL 17.11 listening on `localhost:5432`.
- **Node.js & npm:** Node.js v20+ with npm for asset management and Playwright.

### Safe Database Policy
> [!IMPORTANT]
> **Strict Non-Destructive Database Policy:**
> Do **NOT** run `mix ecto.reset` or `mix ecto.drop`.
> Always apply non-destructive forward migrations using `mix ecto.migrate`.

### Local Setup Steps
```powershell
# Navigate to the repository
Push-Location "C:\Users\rjd42\Documents\sovereign_soul_engine"

# Fetch Elixir dependencies
mix deps.get

# Run pending database migrations
mix ecto.migrate

# Install asset toolchains and build assets
mix assets.setup
mix assets.build

# Start the interactive Phoenix server on port 8561
mix phx.server
```

### Environment Configuration Variables
| Variable | Environment | Required | Description |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` | Prod | Yes | PostgreSQL connection URL (`ecto://USER:PASS@HOST/DATABASE`) |
| `SECRET_KEY_BASE` | Prod | Yes | Session/capsule encryption key (enforced minimum 64 bytes) |
| `STRIPE_SECRET_KEY` | Dev/Prod | Optional | Stripe API secret key for billing |
| `STRIPE_WEBHOOK_SECRET` | Prod | Conditional | Mandatory in `:prod` whenever `STRIPE_SECRET_KEY` is configured |
| `SSE_ADMIN_USER_IDS` | All | Yes (for ACP) | Comma-separated list of confirmed user UUIDs granted ACP access |
| `RELAY_PEERS` | Prod | Optional | Comma-separated list of peer URLs for P2P Soul Society |
| `RELAY_SECRET` | Prod | Conditional | Mandatory in `:prod` whenever `RELAY_PEERS` is configured |
| `PORT` | All | Optional | HTTP server listen port (default: `8561`) |
| `SENTRY_DSN` | Prod | Optional | Sentry error tracking DSN (uses `Sentry.ReqClient`) |
| `ANTHROPIC_API_KEY` | Dev/Prod | Optional | Anthropic Claude API key |
| `OPENAI_API_KEY` | Dev/Prod | Optional | OpenAI API key |
| `GEMINI_API_KEY` | Dev/Prod | Optional | Google Gemini API key |
| `DEEPSEEK_API_KEY` | Dev/Prod | Optional | DeepSeek API key |
| `ELEVENLABS_API_KEY` | Dev/Prod | Optional | ElevenLabs Voice API key |

---

## API Reference & Route Map

| Method | Endpoint | Pipeline / Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/sse/api/webhooks/stripe`, `/api/webhooks/stripe` | `:stripe_webhook` (Stripe-Signature) | Stripe billing webhook ingress with HMAC-SHA256 signature verification |
| `POST` | `/sse/api/webhooks/telegram`, `/api/webhooks/telegram` | `:api` (Bearer Key) | Two-way Telegram bot webhook ingress |
| `POST` | `/sse/api/alexa`, `/api/alexa` | `:api` (Bearer Key) | Amazon Alexa Custom Skill & Echo Show APL endpoint |
| `GET` | `/sse/api/characters` | `:api` (Bearer Key) | List characters |
| `POST` | `/sse/api/characters` | `:api` (Bearer Key) | Create new character |
| `GET` | `/sse/api/characters/:id` | `:api` (Bearer Key) | Fetch character details |
| `GET` | `/sse/api/characters/:id/intent` | `:api` (Bearer Key) | Fetch latest character intent |
| `POST` | `/sse/api/npc_chat` | `:api` (Bearer Key) | Send dialogue to NPC with memory & consequence resolution |
| `GET` | `/sse/api/npc_chat/history` | `:api` (Bearer Key) | Retrieve dialogue history |
| `GET` | `/sse/api/npc_chat/relationship` | `:api` (Bearer Key) | Retrieve directional relationship status |
| `POST` | `/sse/api/ambient_chat/message` | `:api` (Bearer Key) | Ingest ambient conversation |
| `POST` | `/sse/api/ambient_chat/npc_reply` | `:api` (Bearer Key) | Trigger ambient reply |
| `GET` | `/sse/api/npc_actions/pending` | `:api` (Bearer Key) | Fetch pending actions |
| `POST` | `/sse/api/npc_actions/:id/consume` | `:api` (Bearer Key) | Consume pending action |
| `POST` | `/sse/api/telemetry/somatic` | `:api` (Bearer Key) | Ingest somatic telemetry |
| `POST` | `/sse/api/telemetry/wearable` | `:api` (Bearer Key) | Ingest Galaxy Watch, Apple Watch & Smart Ring biometrics |
| `GET` | `/sse/api/telemetry/:slug` | `:api` (Bearer Key) | Retrieve somatic & emotional profile |
| `GET` | `/sse/api/social/feed` | `:api` (Bearer Key) | Retrieve autonomous social feed |
| `GET` | `/sse/api/social/latest/:slug` | `:api` (Bearer Key) | Retrieve latest social post for character |
| `POST` | `/sse/api/social/generate` | `:api` (Bearer Key) | Trigger autonomous social post generation |
| `POST` | `/sse/api/vision/perceive` | `:api` (Bearer Key) | Smart glasses camera image & environmental cognition |
| `GET` | `/sse/api/souls/:slug/export` | `:api` (Bearer Key) | Export portable `.soul` capsule with HMAC signature |
| `POST` | `/sse/api/souls/import` | `:api` (Bearer Key) | Import `.soul` capsule archive |
| `GET` | `/sse/api/smart_home/ambient` | `:api` (Bearer Key) | Query active ambient room lighting profile |
| `POST` | `/sse/api/smart_home/sync` | `:api` (Bearer Key) | Force recalculation and sync to Home Assistant / Hue |
| `GET` | `/sse/api/vessel/display_state` | `:api` (Bearer Key) | Fetch ESP32/OLED desk companion display state |
| `POST` | `/sse/api/vessel/touch` | `:api` (Bearer Key) | Ingest capacitive touch events (pat, stroke, hug) |
| `GET` | `/sse/api/privacy/settings` | `:api` (Bearer Key) | Query user privacy preferences and boundary toggles |
| `POST` | `/sse/api/privacy/settings` | `:api` (Bearer Key) | Update proactive, biometric, vision, and haptic consent settings |
| `POST` | `/sse/api/privacy/safe_word/trigger` | `:api` (Bearer Key) | Activate emergency safe word persona freeze |
| `POST` | `/sse/api/privacy/safe_word/clear` | `:api` (Bearer Key) | Resume standard companion persona dynamics |
| `GET` | `/sse/api/robotics/actuation` | `:api` (Bearer Key) | Fetch kinematics, joint radian targets, and ROS2 packets |
| `POST` | `/sse/api/robotics/telemetry` | `:api` (Bearer Key) | Ingest robot battery, motor temperature, and bumper telemetry |
| `POST` | `/sse/api/memories/purge` | `:api` (Bearer Key) | Selectively purge memories and Theory of Mind knowledge |
| `GET` | `/sse/api/memories/inspect` | `:api` (Bearer Key) | Inspect active episodic and core memories |
| `GET` | `/sse/api/circadian/status` | `:api` (Bearer Key) | Query companion chronotype and circadian phase |
| `POST` | `/sse/api/circadian/chronotype` | `:api` (Bearer Key) | Update companion chronotype |
| `GET` | `/sse/api/souls/dream` | `:api` (Bearer Key) | Retrieve latest subconscious dream narrative |
| `POST` | `/sse/api/souls/dream` | `:api` (Bearer Key) | Trigger REM dream consolidation cycle |
| `GET` | `/sse/api/voice/prosody` | `:api` (Bearer Key) | Fetch acoustic prosody parameters |
| `POST` | `/sse/api/voice/synthesize` | `:api` (Bearer Key) | Synthesize speech with emotional prosody |
| `GET` | `/sse/api/edge/status` | `:api` (Bearer Key) | Query local edge survival mode status |
| `POST` | `/sse/api/edge/toggle` | `:api` (Bearer Key) | Toggle air-gapped local offline mode |
| `GET` | `/sse/api/neighborhood/posts` | `:api` (Bearer Key) | Retrieve hyper-local neighborhood posts |
| `POST` | `/sse/api/neighborhood/posts` | `:api` (Bearer Key) | Create neighborhood board post |
| `POST` | `/sse/api/neighborhood/posts/:id/comment` | `:api` (Bearer Key) | Comment on neighborhood post |
| `POST` | `/sse/api/neighborhood/posts/:id/react` | `:api` (Bearer Key) | React to neighborhood post |
| `POST` | `/sse/api/neighborhood/generate` | `:api` (Bearer Key) | Generate autonomous neighborhood post |
| `POST` | `/sse/api/neighborhood/encounter` | `:api` (Bearer Key) | Ingest local soul encounter |
| `POST` | `/sse/api/relay/inbound` | Public / Relay | Inbound P2P Soul Society envelope (Ed25519 DID signature) |
| `GET` | `/sse/api/relay/peers` | Public / Relay | List connected P2P relay peers |
| `GET` | `/sse/api/world/feed` | Public | Global world event feed |
| `GET` | `/sse/api/town/map` | Public | Spatial town map tiles & grid |
| `GET` | `/sse/api/town/districts/:slug` | Public | District metadata & population |
| `POST` | `/sse/api/town/districts/:slug/expand` | Public | Expand district boundary |
| `POST` | `/sse/api/town/simulate_movements` | Public | Simulate spatial soul movements |
| `POST` | `/sse/api/town/move_soul` | Public | Move individual soul on town map |
| `GET` | `/sse/acp/*` | `:browser` (Admin User) | Admin Control Panel (`SSE_ADMIN_USER_IDS`) |
| `GET` | `/sse/*` | `:browser` (LiveView) | User dashboard, chat, soul creator, ledger, billing |
| `GET/POST` | `/users/*` | `:browser` (Auth) | Registration, login, confirmation, and settings |

---

## Running & Verifying the Test Suite

The Sovereign Soul Engine adheres to a **Strict Zero-Stub Guarantee**. Every module, controller, and background worker contains production logic with 100% test coverage.

### Run ExUnit Backend Tests:
```powershell
Push-Location "C:\Users\rjd42\Documents\sovereign_soul_engine"
mix test
Pop-Location
```
*(1,130+ comprehensive unit, integration, and concurrency tests passing)*

### Run Precommit Verification:
```powershell
Push-Location "C:\Users\rjd42\Documents\sovereign_soul_engine"
mix precommit
Pop-Location
```
*(Executes strict compilation with warnings-as-errors, unused dependency unlock checks, code formatting, and the complete test suite)*

### Run Targeted Test Suites:
```powershell
Push-Location "C:\Users\rjd42\Documents\sovereign_soul_engine"

# Security, access control, and webhook tests:
mix test test/sovereign_soul_engine_web/controllers/api/access_control_test.exs `
         test/sovereign_soul_engine_web/controllers/api/stripe_webhook_controller_test.exs `
         test/sovereign_soul_engine/memories/purge_filters_test.exs

# LiveView and ACP access tests:
mix test test/sovereign_soul_engine_web/live/acp_access_test.exs `
         test/sovereign_soul_engine_web/live/acp_moderation_live_test.exs

# Sockets and channels:
mix test test/sovereign_soul_engine_web/channels/user_socket_test.exs

Pop-Location
```

### Run Playwright End-to-End Tests:
```powershell
Push-Location "C:\Users\rjd42\Documents\sovereign_soul_engine"
npx playwright test --config=test/playwright/playwright.config.js
Pop-Location
```
*(20/20 end-to-end browser tests verifying LiveView chat, biometric HUDs, privacy shield drawer, safe word freeze, and visual perception)*

---

*Engine crafted by Goose Tech Industries.*
