#!/bin/bash
set -euo pipefail

if pgrep -fal llama-server >/dev/null 2>&1; then
  echo "Stopping llama-server..."
  pkill -f llama-server
  sleep 1
  if pgrep -fal llama-server >/dev/null 2>&1; then
    echo "llama-server is still running. You may need to stop it manually." >&2
    exit 1
  fi
  echo "llama-server stopped."
else
  echo "No llama-server process found."
fi
