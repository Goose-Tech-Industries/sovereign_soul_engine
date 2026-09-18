"""
Sovereign Soul Engine - Serverless LoRA Fine-Tuner (Modal Labs)
Trains Sovereign Soul Foundation or Character LoRA adapters on cloud GPUs (A100 / L40S)
in ~20 minutes for under $1.50 with zero local GPU requirements.

Setup:
  pip install modal
  modal setup

Run:
  modal run tools/llm_training/train_modal_lora.py --dataset tools/llm_training/sovereign_soul_foundation_dataset.jsonl
"""

try:
    import modal
except ImportError:
    modal = None

if modal is not None:
    app = modal.App("sovereign-soul-lora-trainer")

    # Docker image with Unsloth and PyTorch CUDA 12.1 pre-configured
    image = (
        modal.Image.debian_slim(python_version="3.11")
        .pip_install(
            "torch>=2.2.0",
            "transformers",
            "datasets",
            "accelerate",
            "peft",
            "bitsandbytes",
            "trl",
            "sentencepiece",
        )
        .run_commands(
            "pip install 'unsloth[cu121-torch220] @ git+https://github.com/unslothai/unsloth.git'"
        )
    )

    volume = modal.Volume.from_name("sovereign-soul-weights", create_if_missing=True)

    @app.function(
        image=image,
        gpu="A100",  # 40GB or 80GB A100 GPU
        timeout=3600,
        volumes={"/weights": volume}
    )
    def train_lora_cloud(dataset_jsonl_content: str, model_name: str = "sovereign_soul_foundation"):
        import os
        import torch
        from unsloth import FastLanguageModel
        from trl import SFTTrainer
        from transformers import TrainingArguments
        from datasets import Dataset
        import json

        print(f"=== SOVEREIGN SOUL ENGINE: TRAINING {model_name.upper()} ===")
        
        # 1. Parse dataset from in-memory string
        lines = [json.loads(line) for line in dataset_jsonl_content.strip().split("\n") if line.strip()]
        hf_dataset = Dataset.from_list(lines)

        # 2. Load 4-bit Base Model
        max_seq_length = 2048
        model, tokenizer = FastLanguageModel.from_pretrained(
            model_name="unsloth/Meta-Llama-3.1-8B-Instruct-bnb-4bit",
            max_seq_length=max_seq_length,
            load_in_4bit=True
        )

        # 3. Configure PEFT LoRA
        model = FastLanguageModel.get_peft_model(
            model,
            r=16,
            target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
            lora_alpha=16,
            lora_dropout=0,
            bias="none",
            use_gradient_checkpointing="unsloth",
            random_state=3407
        )

        # 4. Format Prompts
        def format_prompts(batch):
            texts = [
                tokenizer.apply_chat_template(convos, tokenize=False, add_generation_prompt=False)
                for convos in batch["messages"]
            ]
            return {"text": texts}

        formatted_dataset = hf_dataset.map(format_prompts, batched=True)

        # 5. Execute Training
        trainer = SFTTrainer(
            model=model,
            tokenizer=tokenizer,
            train_dataset=formatted_dataset,
            dataset_text_field="text",
            max_seq_length=max_seq_length,
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
                output_dir="/tmp/outputs"
            )
        )

        trainer.train()

        # 6. Save directly to persistent Modal Volume
        out_lora = f"/weights/{model_name}_peft"
        out_gguf = f"/weights/{model_name}_q4"
        
        print(f"Saving PEFT adapter to {out_lora}...")
        model.save_pretrained_merged(out_lora, tokenizer, save_method="lora")
        
        print(f"Saving Quantized GGUF to {out_gguf}...")
        model.save_pretrained_gguf(out_gguf, tokenizer, quantization_method="q4_k_m")

        volume.commit()
        print("=== TRAINING COMPLETE: WEIGHTS COMMITTED TO CLOUD VOLUME ===")
        return {"status": "success", "peft_path": out_lora, "gguf_path": out_gguf}

    @app.local_entrypoint()
    def main(dataset: str = "tools/llm_training/sovereign_soul_foundation_dataset.jsonl", name: str = "sovereign_soul_foundation"):
        with open(dataset, "r", encoding="utf-8") as f:
            content = f.read()
        print(f"Dispatching training job to Modal A100 GPU...")
        result = train_lora_cloud.remote(content, name)
        print("Result:", result)
else:
    def main():
        print("Modal SDK not installed. Run 'pip install modal' to use serverless cloud training.")
    if __name__ == "__main__":
        main()
