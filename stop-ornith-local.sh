#!/bin/bash
set -euo pipefail

MODEL="${MODEL:-$HOME/models/ornith-1.0-35b-Q4_K_M.gguf}"
MODEL_BASENAME="$(basename "$MODEL")"

PIDS="$(ps -axo pid=,command= | awk -v model="$MODEL" -v base="$MODEL_BASENAME" '
  /llama-server/ && (index($0, model) || index($0, base)) { print $1 }
')"

if [ -z "$PIDS" ]; then
  echo "No Ornith llama-server process found."
  exit 0
fi

echo "Stopping Ornith llama-server: $PIDS"
# shellcheck disable=SC2086
kill $PIDS
sleep 1

REMAINING="$(ps -axo pid=,command= | awk -v model="$MODEL" -v base="$MODEL_BASENAME" '
  /llama-server/ && (index($0, model) || index($0, base)) { print $1 }
')"

if [ -n "$REMAINING" ]; then
  echo "Ornith llama-server is still running: $REMAINING" >&2
  echo "Trying SIGKILL..." >&2
  # shellcheck disable=SC2086
  kill -9 $REMAINING
  sleep 1
fi

REMAINING="$(ps -axo pid=,command= | awk -v model="$MODEL" -v base="$MODEL_BASENAME" '
  /llama-server/ && (index($0, model) || index($0, base)) { print $1 }
')"

if [ -n "$REMAINING" ]; then
  echo "Ornith llama-server is still running. Stop it manually: $REMAINING" >&2
  exit 1
fi

echo "Ornith llama-server stopped."