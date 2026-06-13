#!/bin/bash
set -euo pipefail

PORT="${PORT:-8080}"

echo "== llama-server process =="
if ! pgrep -fal llama-server; then
  echo "No llama-server process found."
fi

echo
echo "== Port $PORT =="
if ! lsof -nP -iTCP:"$PORT" -sTCP:LISTEN; then
  echo "Nothing is listening on port $PORT."
fi

echo
echo "== HTTP health check =="
if command -v curl >/dev/null 2>&1; then
  if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "Server responded on /health"
  else
    echo "Server did not respond on /health"
  fi
else
  echo "curl not found; skipping HTTP check"
fi
