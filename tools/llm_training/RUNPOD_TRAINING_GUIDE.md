# Sovereign Soul Engine - Cloud LoRA Training & Deployment Guide

This guide walks you through fine-tuning your own uncensored companion LLM on **RunPod** (or Lambda Labs) for **~$3.00 to $5.00 total**, and deploying it for high-speed inference.

---

## 1. Renting a Cloud GPU Pod (RunPod)

1. Sign up at [RunPod.io](https://www.runpod.io) and deposit **$10**.
2. Click **Deploy** -> **Community Cloud** or **Secure Cloud**.
3. Select an **NVIDIA A100 (80GB VRAM)** or **RTX 4090 (24GB VRAM)**.
   - Rate: ~$0.50/hr (RTX 4090) to ~$1.89/hr (A100).
4. Template: Select **RunPod PyTorch 2.2** or **FastAI**.
5. Set Container Disk to **40 GB** and Volume Disk to **40 GB**.
6. Click **Deploy**.

---

## 2. Running the Training Script

1. Once the Pod starts, click **Connect** -> **Start Web Terminal** (or Jupyter Lab).
2. Install Unsloth:
   ```bash
   pip install "unsloth[cu121-torch220] @ git+https://github.com/unslothai/unsloth.git"
   pip install "xformers<0.0.28" "trl<0.9.0" peft accelerate bitsandbytes
   ```
3. Upload `sovereign_soul_lora_dataset.jsonl` and `train_runpod_unsloth.py` using Jupyter file drag-and-drop.
4. Run the training script:
   ```bash
   python train_runpod_unsloth.py
   ```
5. **Execution time:** ~35–60 minutes.
   - It will output `sovereign_soul_8b_q4.gguf` (for local Ollama) and `sovereign_soul_8b_lora` (for cloud vLLM).

---

## 3. Serving the Model (Inference)

### Option A: Serve on RunPod with vLLM (Cloud Web Server)
RunPod offers 1-click vLLM serverless endpoints or you can keep your pod running vLLM:
```bash
python -m vllm.entrypoints.openai.api_server \
    --model ./sovereign_soul_8b_lora \
    --port 8000 \
    --max-model-len 4096
```
In your Sovereign Soul Engine `.env` or `config/dev.exs`:
```elixir
config :sovereign_soul_engine,
  local_llm_url: "https://your-pod-id-8000.proxy.runpod.net/v1/chat/completions"
```
Companions will respond in **sub-1-second** with 80+ tokens/sec!

### Option B: Download the GGUF to Your PC (Local Offline)
Download `sovereign_soul_8b_q4.gguf` to your PC.
Import to Ollama with a simple `Modelfile`:
```dockerfile
FROM ./sovereign_soul_8b_q4.gguf
TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>

{{ .System }}<|eot_id|>{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>

{{ .Prompt }}<|eot_id|>{{ end }}<|start_header_id|>assistant<|end_header_id|>

{{ .Response }}<|eot_id|>"""
PARAMETER stop "<|start_header_id|>"
PARAMETER stop "<|end_header_id|>"
PARAMETER stop "<|eot_id|>"
```
Run:
```bash
ollama create sovereign-soul -f Modelfile
```
Now you have your own 100% private, customized companion brain!
