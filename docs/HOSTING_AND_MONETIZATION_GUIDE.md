# Sovereign Soul Engine — Production Hosting & Monetization Architecture

This guide details exactly **where and how to host your fine-tuned LoRA models** for the consumer companion app, and the **commercial business models** to monetize both game studios and companion creators.

---

## Part 1: Where to Host the LoRA Model for Your Companion App

When paying subscribers on Web, iOS, Android, or PWA chat with companions on the Phoenix engine (`http://localhost:8561` or `https://your-app.fly.dev`), here is where the model runs in production:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Client Layer (Web / PWA / iOS / Android)                    │
│           Subscribers ($14.99 Companion / $19.99 Archon 18+)                │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ HTTPS / WebSockets
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                  Sovereign Soul Phoenix Server (Fly.io)                     │
│         - Stripe Billing & Age Gate   - Ecto Memory & Grudge Vault          │
│         - Somatic Biometrics          - Circuit Breaker & Safe Word         │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ REST (/v1/chat/completions)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Production Inference Options                        │
│                                                                             │
│  [Option 1: Serverless vLLM]          [Option 2: Dedicated GPU Cluster]     │
│  - Modal Labs / RunPod Serverless     - RunPod / Lambda Labs (RTX 4090)     │
│  - $0.00 idle cost                    - $0.44/hr ($315/month)               │
│  - Scales to 0 when users sleep       - Break-even at 21 subscribers        │
│  - Best for Launch                    - 90% profit margin at scale          │
│                                                                             │
│  [Option 3: Managed LoRA API (Together.ai / Fireworks.ai)]                  │
│  - Zero GPU DevOps, upload LoRA adapter directly                            │
│  - $0.20 per 1M tokens, 99.99% enterprise uptime                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### Option 1: Serverless vLLM on Modal Labs (Recommended for Launch)

- **How it works:**
  Modal boots up a fast A100 or L40S GPU container on demand running vLLM. It caches the base model (`Meta-Llama-3.1-8B-Instruct`) and attaches your LoRA adapter (`sovereign_soul_foundation_peft`).
- **Cost:**
  - **$0.00 when nobody is chatting.**
  - ~$0.0003 per chat turn when active.
  - 10,000 chat messages cost ~$3.00.
- **Connecting in Sovereign Soul Engine (`.env`):**
  ```bash
  LOCAL_LLM_URL="https://your-org--sovereign-soul-vllm.modal.run/v1/chat/completions"
  LOCAL_LLM_MODEL="sovereign_soul_foundation"
  ```

---

### Option 2: Dedicated Cloud GPU with Multi-LoRA (Best at 25+ Subscribers)

- **How it works:**
  Rent a dedicated **NVIDIA RTX 4090 (24GB VRAM)** on RunPod Secure Cloud or Lambda Labs.
  Run vLLM with `--enable-lora`:
  ```bash
  python -m vllm.entrypoints.openai.api_server \
      --model meta-llama/Meta-Llama-3.1-8B-Instruct \
      --enable-lora \
      --lora-modules foundation=./weights/foundation maya=./weights/maya \
      --port 8000
  ```
  **The Multi-LoRA Superpower:** A single $0.44/hr GPU server holds 50+ companion LoRA adapters in RAM/VRAM simultaneously. When a user talks to Maya, vLLM loads Maya's 30MB adapter into the forward pass in **under 2 milliseconds**.
- **The Financial Unit Economics:**
  - Server Cost: $0.44/hr = **~$315 / month**.
  - Capacity: ~40 concurrent streams, ~100,000 messages / day.
  - **Break-Even:**
    - 21 Companion subscribers ($14.99) = $314.79 gross (100% server covered).
    - 16 Archon subscribers ($19.99) = $319.84 gross (100% server covered).
  - **At 200 Subscribers:**
    - Gross Revenue: $3,500 / month.
    - Server Cost: $315 / month.
    - Stripe Fees: ~$105 / month.
    - **Net Profit: $3,080 / month (>88% profit margin).**

---

### Option 3: Managed LoRA Hosting on Together.ai / Fireworks.ai (Zero DevOps)

- Upload your fine-tuned LoRA weights directly to Together.ai:
  ```bash
  together models upload --model-name "sovereign-soul-foundation-8b" --adapter-path ./outputs/sovereign_soul_foundation_peft
  ```
- Together hosts it permanently across global clusters.
- Cost is ~$0.20 per 1M tokens. Zero servers to manage, monitor, or patch.

---

## Part 2: How to Monetize Game Studios & Creators

### 1. Game Studios (B2B Middleware Model)

Game studios reject per-API-token metered pricing (like Inworld AI) because unpredictable cloud bills destroy game economics if a title sells 500,000 copies on Steam.

We monetize studios using the **Annual Title License + Revenue Share Cap** (The Unreal Engine & Wwise industry standard):

| Tier | Price | Who It Is For | What They Get |
|---|---|---|---|
| **Indie Studio** | **$499 / year** per title | Revenue < $100k USD (or 5% royalty above $100k) | • Unity (C#) & Unreal (C++) native SDKs<br>• Model 1: In-Context Engine<br>• Local offline GGUF runtime (zero cloud costs)<br>• Community Discord support |
| **Pro Studio** | **$4,999 / year** per title | Revenue $100k – $2M USD | • Model 2: Sovereign Soul Foundation LoRA weights<br>• Sub-second multi-NPC relay server<br>• Commercial Safe-Harbor legal indemnification<br>• Private engineering Slack SLA |
| **Enterprise / AAA** | **$24,999 – $49,999 / year** per title | Revenue > $2M USD | • Model 3: Character LoRA Forge toolchain<br>• Custom fine-tuning on studio lore bibles<br>• On-premise air-gapped deployment<br>• Dedicated lead AI engineer |

**Why Studios Sign Annual Licenses:**
- Predictable budget for their production cycle (1–3 year development).
- Zero per-call inference bills—the game runs on the player's own GPU or the studio's dedicated servers.

---

### 2. Companion Creators (UGC Creator Economy)

For independent creators (writers, VTubers, roleplayers, dungeon masters) who build companions for your consumer app:

1. **80 / 20 Subscription Revenue Split:**
   - Creator designs a character and publishes it on your Companion App feed (`/sse/feed`).
   - Fans subscribe at **$14.99 / month** or **$19.99 / month** (Archon 18+ Uncensored).
   - **Creator receives 80%** ($11.99 or $15.99 / mo).
   - **Platform keeps 20%** ($3.00 or $4.00 / mo).
   - *Platform cost per user is only ~$0.30 in GPU compute, netting you ~$2.50 to $3.50 pure margin per subscriber.*

2. **The Character Forge Fee ($29 – $49 one-time):**
   - When a creator wants a bespoke fine-tuned LoRA adapter made from their character sheet or `.soul` file:
   - They pay **$29.00 USD**.
   - Your automated pipeline (`character_lora_forge.py` + `train_modal_lora.py`) trains the adapter on a cloud A100 in 15 minutes for **$1.20**.
   - **Instant profit: $27.80 per character forged.**

---

## Part 3: Quickstart Execution Checklist

To train and launch right now:

1. **Generate Foundation Dataset:**
   ```bash
   python tools/llm_training/generate_foundation_dataset.py
   ```
2. **Train LoRA Adapter:**
   - **Option A (Modal - 1-Click Serverless Cloud):**
     ```bash
     modal run tools/llm_training/train_modal_lora.py
     ```
   - **Option B (RunPod / Dedicated GPU):**
     Follow [`tools/llm_training/RUNPOD_TRAINING_GUIDE.md`](file:///C:/Users/rjd42/Desktop/sovereign_soul_engine/tools/llm_training/RUNPOD_TRAINING_GUIDE.md) using `train_runpod_unsloth.py`.
3. **Deploy Inference Endpoint:**
   Launch vLLM or point to Modal, and add `LOCAL_LLM_URL` to your production environment.
4. **License Studios & Onboard Creators:**
   Send [`docs/studio_pitch.md`](file:///C:/Users/rjd42/Desktop/sovereign_soul_engine/docs/studio_pitch.md) with the $499 / $4,999 / $24,999 annual tiers.
