"""
Sovereign Soul Engine - Cloud LoRA Training Script (Unsloth + LLaMA 3.1 8B)
Designed to run on a rented RunPod / Lambda Labs instance with an A100 (80GB) or RTX 4090.
Cost: ~$1.50/hr on RunPod, takes ~45-90 minutes total.

Dependencies (RunPod template):
pip install unsloth "xformers<0.0.28" "trl<0.9.0" peft accelerate bitsandbytes
"""

import torch
from unsloth import FastLanguageModel
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset

# 1. Model Configuration
max_seq_length = 2048
dtype = None # Auto detection (Float16 for Tesla T4, Bfloat16 for Ampere/Ada/Hopper)
load_in_4bit = True # 4bit QLoRA for maximum memory efficiency

print("Loading base model: meta-llama/Meta-Llama-3.1-8B-Instruct...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Meta-Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=max_seq_length,
    dtype=dtype,
    load_in_4bit=load_in_4bit,
)

# 2. Add LoRA Adapters
model = FastLanguageModel.get_peft_model(
    model,
    r=16, # Rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0, # Optimized for unsloth
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
)

# 3. Load Custom Sovereign Soul Dataset
print("Loading custom Sovereign Soul dataset...")
dataset = load_dataset("json", data_files="sovereign_soul_lora_dataset.jsonl", split="train")

def formatting_prompts_func(examples):
    convos = examples["messages"]
    texts = [tokenizer.apply_chat_template(convo, tokenize=False, add_generation_prompt=False) for convo in convos]
    return {"text": texts}

dataset = dataset.map(formatting_prompts_func, batched=True)

# 4. Initialize Trainer
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=max_seq_length,
    dataset_num_proc=2,
    packing=False,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=60,
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=1,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir="outputs",
    ),
)

# 5. Train
print("\n=== STARTING UNSLOTH LORA FINE-TUNING ===")
trainer_stats = trainer.train()
print(f"Training completed in {trainer_stats.metrics['train_runtime']:.2f} seconds!")

# 6. Save LoRA Adapter and GGUF
print("\nSaving 16-bit merged model and GGUF weights...")
model.save_pretrained_merged("sovereign_soul_8b_lora", tokenizer, save_method="merged_16bit")
model.save_pretrained_gguf("sovereign_soul_8b_q4", tokenizer, quantization_method="q4_k_m")

print("\nAll done! Weights saved:")
print("-> sovereign_soul_8b_lora (for vLLM cloud deployment)")
print("-> sovereign_soul_8b_q4 (for local Ollama deployment)")
