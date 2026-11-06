"""Expand a Llama GQA checkpoint to full MHA before AWQ quantization.

TinyLlama uses 32 query heads and 4 shared KV heads.  The existing FPGA
scheduler consumes one K/V head per query head.  Repeating each K/V projection
block here is equivalent to Transformers' runtime repeat_kv operation.
"""

import argparse
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer


def expand_projection(
    linear: torch.nn.Linear, kv_heads: int, repeats: int
) -> torch.nn.Linear:
    weight = linear.weight.detach()
    head_dim = weight.shape[0] // kv_heads
    expanded = (
        weight.reshape(kv_heads, head_dim, weight.shape[1])
        .repeat_interleave(repeats, dim=0)
        .reshape(-1, weight.shape[1])
    )
    result = torch.nn.Linear(
        linear.in_features,
        expanded.shape[0],
        bias=linear.bias is not None,
        dtype=weight.dtype,
        device=weight.device,
    )
    result.weight.data.copy_(expanded)
    if linear.bias is not None:
        expanded_bias = (
            linear.bias.detach()
            .reshape(kv_heads, head_dim)
            .repeat_interleave(repeats, dim=0)
            .reshape(-1)
        )
        result.bias.data.copy_(expanded_bias)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_model")
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    model = AutoModelForCausalLM.from_pretrained(
        args.input_model, torch_dtype=torch.float16, low_cpu_mem_usage=True
    )
    q_heads = model.config.num_attention_heads
    kv_heads = model.config.num_key_value_heads
    if q_heads % kv_heads:
        raise ValueError(f"query heads {q_heads} not divisible by KV heads {kv_heads}")
    repeats = q_heads // kv_heads
    if repeats == 1:
        raise ValueError("checkpoint is already full MHA")

    for layer in model.model.layers:
        attn = layer.self_attn
        attn.k_proj = expand_projection(attn.k_proj, kv_heads, repeats)
        attn.v_proj = expand_projection(attn.v_proj, kv_heads, repeats)
        attn.num_key_value_heads = q_heads
        attn.num_key_value_groups = 1

    model.config.num_key_value_heads = q_heads
    args.output_dir.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(args.output_dir, safe_serialization=True)
    AutoTokenizer.from_pretrained(args.input_model).save_pretrained(args.output_dir)


if __name__ == "__main__":
    main()
