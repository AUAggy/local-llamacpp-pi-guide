#!/bin/bash
set -euo pipefail

# Override these with environment variables if your local paths differ.
LLAMA_DIR="${LLAMA_DIR:-/path/to/llama.cpp}"
MODEL="${MODEL:-$HOME/models/gemma-4-31B-it-Q4_K_M.gguf}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
CTX_SIZE="${CTX_SIZE:-4096}"

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

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  if ps -axo command= | grep -F "llama-server" | grep -F "$MODEL" >/dev/null 2>&1; then
    echo "Gemma 4 llama-server already appears to be running on $HOST:$PORT"
    exit 0
  fi

  echo "Port $PORT is already in use. Stop the current local model before starting Gemma 4." >&2
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2 || true
  exit 1
fi

exec "$LLAMA_DIR/build/bin/llama-server" \
  -m "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  -ngl 999 \
  -c "$CTX_SIZE" \
  --flash-attn on \
  --temp 0.6 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0
