#!/bin/bash
set -euo pipefail

# Override these with environment variables if your local paths differ.
LLAMA_DIR="${LLAMA_DIR:-/path/to/llama.cpp}"
MODEL="${MODEL:-$HOME/models/Qwen3.6-27B-Q4_K_M.gguf}"
PORT="${PORT:-8080}"
CTX_SIZE="${CTX_SIZE:-65536}"

if [ ! -x "$LLAMA_DIR/build/bin/llama-server" ]; then
  echo "llama-server not found at: $LLAMA_DIR/build/bin/llama-server" >&2
  echo "Set LLAMA_DIR to your local llama.cpp checkout path." >&2
  exit 1
fi

if [ ! -f "$MODEL" ]; then
  echo "Model not found at: $MODEL" >&2
  echo "Set MODEL to your local GGUF path, or move the model into ~/models." >&2
  exit 1
fi

exec "$LLAMA_DIR/build/bin/llama-server" \
  -m "$MODEL" \
  --host 127.0.0.1 \
  --port "$PORT" \
  -ngl 999 \
  -c "$CTX_SIZE" \
  --flash-attn on \
  --chat-template-kwargs '{"enable_thinking":true}'
