#!/usr/bin/env python
"""
Selective Context Prompt Compression CLI for Baseline.

Implements the Selective Context algorithm (Li et al., 2023) for prompt compression.
Uses self-information from a small language model (GPT-2) to identify and remove
less informative content units, reducing prompt length while preserving key information.

Unlike the original `selective-context` package, this implementation avoids spacy
dependency conflicts by using a simpler sentence/phrase splitting approach.

Usage:
    python selective_context.py "prompt text to compress"
    echo "long prompt" | python selective_context.py --stdin
    python selective_context.py --ratio 0.5 --unit sentence "prompt text"

Environment variables:
    SC_MODEL — HuggingFace model name or local path (default: gpt2)
    SC_REDUCE_RATIO — Reduction ratio (default: 0.5, meaning remove 50%)
    SC_UNIT — Content unit: "sentence", "phrase", or "token" (default: sentence)
"""

import argparse
import json
import math
import os
import re
import sys
from typing import List, Tuple

import torch
import numpy as np

# Config
MODEL_NAME = os.environ.get("SC_MODEL", "gpt2")
DEFAULT_RATIO = float(os.environ.get("SC_REDUCE_RATIO", "0.4"))
DEFAULT_UNIT = os.environ.get("SC_UNIT", "sentence")

# Lazy-load model
_model = None
_tokenizer = None


def _load_model():
    global _model, _tokenizer
    if _model is None:
        from transformers import GPT2LMHeadModel, GPT2Tokenizer
        _tokenizer = GPT2Tokenizer.from_pretrained(MODEL_NAME)
        _model = GPT2LMHeadModel.from_pretrained(MODEL_NAME)
        _model.eval()
    return _model, _tokenizer


def _split_sentences(text: str) -> List[str]:
    """Split text into sentences using regex (no spacy needed)."""
    # Split on sentence-ending punctuation followed by space or newline
    parts = re.split(r'(?<=[.!?])\s+|\n+', text)
    return [p.strip() for p in parts if p.strip()]


def _split_phrases(text: str) -> List[str]:
    """Split text into phrases (clauses separated by commas, semicolons, etc.)."""
    parts = re.split(r'[,;:]\s*|\n+', text)
    return [p.strip() for p in parts if p.strip()]


def _compute_self_information(text: str) -> List[Tuple[str, float]]:
    """Compute self-information for each token in the text.
    
    Self-information = -log2(P(token | context))
    Higher self-information = more informative/surprising token
    """
    model, tokenizer = _load_model()
    
    tokens = tokenizer.encode(text, return_tensors="pt")
    if tokens.shape[1] == 0:
        return []
    
    with torch.no_grad():
        outputs = model(tokens, labels=tokens)
        logits = outputs.logits
    
    # Compute per-token log probabilities
    log_probs = torch.nn.functional.log_softmax(logits, dim=-1)
    
    token_info = []
    for i in range(1, tokens.shape[1]):
        token_id = tokens[0, i].item()
        log_prob = log_probs[0, i - 1, token_id].item()
        self_info = -log_prob / math.log(2)  # Convert to bits
        token_text = tokenizer.decode([token_id])
        token_info.append((token_text, self_info))
    
    return token_info


def _compute_unit_self_information(text: str, unit: str = "sentence") -> List[Tuple[str, float]]:
    """Compute average self-information per content unit."""
    if unit == "sentence":
        units = _split_sentences(text)
    elif unit == "phrase":
        units = _split_phrases(text)
    else:  # token level
        return _compute_self_information(text)
    
    model, tokenizer = _load_model()
    
    unit_scores = []
    for u in units:
        tokens = tokenizer.encode(u)
        if len(tokens) == 0:
            unit_scores.append((u, 0.0))
            continue
        
        input_ids = torch.tensor([tokens])
        with torch.no_grad():
            outputs = model(input_ids, labels=input_ids)
            logits = outputs.logits
        
        log_probs = torch.nn.functional.log_softmax(logits, dim=-1)
        
        total_info = 0.0
        count = 0
        for i in range(1, len(tokens)):
            token_id = tokens[i]
            log_prob = log_probs[0, i - 1, token_id].item()
            total_info += -log_prob / math.log(2)
            count += 1
        
        avg_info = total_info / max(count, 1)
        unit_scores.append((u, avg_info))
    
    return unit_scores


def compress(text: str, reduce_ratio: float = DEFAULT_RATIO, unit: str = DEFAULT_UNIT) -> dict:
    """Compress text using Selective Context algorithm.
    
    Args:
        text: Input text to compress
        reduce_ratio: Fraction of content to remove (0.5 = remove 50%)
        unit: Content unit for selection ("sentence", "phrase", "token")
    
    Returns:
        Dict with compressed_text, original_length, compressed_length, etc.
    """
    if not text.strip():
        return {
            "compressed_text": text,
            "original_tokens": 0,
            "compressed_tokens": 0,
            "reduction_pct": 0,
        }
    
    unit_scores = _compute_unit_self_information(text, unit)
    
    if not unit_scores:
        return {
            "compressed_text": text,
            "original_tokens": 0,
            "compressed_tokens": 0,
            "reduction_pct": 0,
        }
    
    # Sort by self-information (ascending = least informative first)
    sorted_units = sorted(enumerate(unit_scores), key=lambda x: x[1][1])
    
    # Remove the least informative units up to reduce_ratio
    n_remove = int(len(sorted_units) * reduce_ratio)
    remove_indices = set(idx for idx, _ in sorted_units[:n_remove])
    
    # Reconstruct text keeping only the informative units
    kept_units = [
        unit_scores[i][0]
        for i in range(len(unit_scores))
        if i not in remove_indices
    ]
    
    if unit == "token":
        compressed = "".join(kept_units)
    else:
        compressed = " ".join(kept_units)
    
    _, tokenizer = _load_model()
    orig_tokens = len(tokenizer.encode(text))
    comp_tokens = len(tokenizer.encode(compressed))
    
    return {
        "compressed_text": compressed,
        "original_tokens": orig_tokens,
        "compressed_tokens": comp_tokens,
        "reduction_pct": round((1 - comp_tokens / max(orig_tokens, 1)) * 100, 1),
    }


def main():
    parser = argparse.ArgumentParser(description="Selective Context Prompt Compressor")
    parser.add_argument("text", nargs="?", help="Text to compress")
    parser.add_argument("--stdin", action="store_true", help="Read from stdin")
    parser.add_argument("--ratio", type=float, default=DEFAULT_RATIO, help="Reduction ratio")
    parser.add_argument("--unit", default=DEFAULT_UNIT, choices=["sentence", "phrase", "token"])
    parser.add_argument("--json", action="store_true", help="Output JSON result")
    args = parser.parse_args()

    if args.stdin:
        text = sys.stdin.read()
    elif args.text:
        text = args.text
    else:
        parser.print_help()
        sys.exit(1)

    if not text.strip():
        print("", end="")
        sys.exit(0)

    result = compress(text.strip(), reduce_ratio=args.ratio, unit=args.unit)

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(result["compressed_text"], end="")


if __name__ == "__main__":
    main()