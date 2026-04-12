#!/usr/bin/env python
"""
LLMLingua-2 Prompt Compression CLI for Baseline.

Compresses prompt text using Microsoft's LLMLingua-2 to reduce token count
while preserving key information.

Usage:
    python llmlingua_compress.py "prompt text to compress"
    echo "long prompt" | python llmlingua_compress.py --stdin
    python llmlingua_compress.py --rate 0.5 "prompt text"

Environment variables:
    LLMLINGUA_MODEL — Path to local LLMLingua-2 model
    LLMLINGUA_RATE — Compression rate (default: 0.5, meaning keep 50% of tokens)
    LLMLINGUA_DEVICE — Device to use (default: cpu)
"""

import argparse
import json
import os
import sys

# Model path
MODEL_PATH = os.environ.get(
    "LLMLINGUA_MODEL",
    os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "local_models/llmlingua-2-xlm-roberta-large-meetingbank",
    ),
)
DEFAULT_RATE = float(os.environ.get("LLMLINGUA_RATE", "0.4"))
DEVICE = os.environ.get("LLMLINGUA_DEVICE", "cpu")

# Lazy-load compressor (heavy import)
_compressor = None


def get_compressor():
    global _compressor
    if _compressor is None:
        from llmlingua import PromptCompressor

        _compressor = PromptCompressor(
            model_name=MODEL_PATH,
            use_llmlingua2=True,
            device_map=DEVICE,
        )
    return _compressor


def compress(text, rate=DEFAULT_RATE):
    """Compress text and return result dict."""
    compressor = get_compressor()
    result = compressor.compress_prompt(
        text,
        rate=rate,
        force_tokens=["\n", "?", ".", "!", ",", ":", ";", "-", "(", ")", "[", "]", "{", "}"],
    )
    return {
        "compressed_prompt": result["compressed_prompt"],
        "origin_tokens": int(result["origin_tokens"]),
        "compressed_tokens": int(result["compressed_tokens"]),
        "ratio": str(result["ratio"]),
        "saving_pct": round(
            (1 - int(result["compressed_tokens"]) / max(int(result["origin_tokens"]), 1)) * 100,
            1,
        ),
    }


def main():
    parser = argparse.ArgumentParser(description="LLMLingua-2 Prompt Compressor")
    parser.add_argument("text", nargs="?", help="Text to compress")
    parser.add_argument("--stdin", action="store_true", help="Read text from stdin")
    parser.add_argument("--rate", type=float, default=DEFAULT_RATE, help="Compression rate (0-1)")
    parser.add_argument("--json", action="store_true", help="Output full JSON result")
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

    result = compress(text.strip(), rate=args.rate)

    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        # Just output the compressed text
        print(result["compressed_prompt"], end="")


if __name__ == "__main__":
    main()