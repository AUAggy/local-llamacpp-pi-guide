# Running Pi with local llama.cpp models on an M1 Max with 32 GB RAM

This is a practical guide for running Pi against a local `llama.cpp` server on Apple Silicon.

It was validated on an M1 Max with 32 GB unified memory using these local GGUF models:

- `Qwen3.6-27B-Q4_K_M.gguf`
- `gemma-4-31B-it-Q4_K_M.gguf`

The guide started as a Qwen-only setup, but it now covers switching between multiple local `llama.cpp` models. The recommended folder/repo name is now:

```text
local-llamacpp-pi-guide
```

---

## Key idea

Use one `llama-server` endpoint at a time:

```text
http://127.0.0.1:8080/v1
```

Pi can list both Qwen and Gemma, but `llama-server` only serves the model that was loaded when the server started.

So switching models means:

1. stop the currently running local model
2. start the other local model
3. select the matching model inside Pi with `/model`

On a 32 GB M1 Max, do not try to keep Qwen 27B Q4 and Gemma 31B Q4 loaded at the same time.

---

## What worked

- `llama.cpp` built from source with Metal enabled
- `Qwen3.6-27B-Q4_K_M.gguf` loaded successfully
- `gemma-4-31B-it-Q4_K_M.gguf` loaded successfully at 4k context
- Pi connected to the local OpenAI-compatible endpoint
- Pi model selection worked with local models
- Qwen tool calling worked in a smoke test
- Gemma direct HTTP smoke test returned a valid answer

Update note, 2026-06-11: the local source checkout was upgraded from `b8953` to `b9592` using a fresh CMake build directory. Recent `llama.cpp` releases prefer `--reasoning on` over the older `--chat-template-kwargs '{"enable_thinking":true}'` CLI flag for Qwen.

Update note, 2026-06-13: Gemma 4 31B Q4_K_M was added and validated at `-c 4096`. In a simple local test, Gemma ran around 10.8 tok/s and Qwen around 12.6 tok/s. Treat this as a rough smoke-test comparison, not a full model benchmark.

---

## Why build llama.cpp from source

On Apple Silicon, Homebrew is convenient but not the safest option if you care about Metal acceleration and reproducibility.

Building from source makes the backend choice explicit and avoids ambiguity about how `ggml` was built.

Use CMake with Metal enabled:

```bash
cmake -B build \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DLLAMA_BUILD_TESTS=OFF
```

If old OpenSSL headers in `/usr/local/include/openssl` shadow Homebrew OpenSSL 3, force the compiler paths:

```bash
export CFLAGS="-I/opt/homebrew/opt/openssl@3/include"
export CXXFLAGS="-I/opt/homebrew/opt/openssl@3/include"
export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"
```

---

## Model choices

### Qwen

```text
Qwen3.6-27B-Q4_K_M.gguf
```

Why this quant:

- good quality for the memory budget
- small enough to fit on a 32 GB machine
- capable enough for coding tasks
- validated with Pi tool calling

Qwen was tested with a large context:

```text
-c 65536
```

### Gemma

```text
gemma-4-31B-it-Q4_K_M.gguf
```

Why this quant:

- best first quality target for a 31B-class model on 32 GB unified memory
- fits at 4k context in local testing
- slower than Qwen 27B Q4, but usable

Gemma should start conservatively:

```text
-c 4096
```

If 4k is stable, test larger context gradually:

```text
4096 -> 8192 -> 12288 -> 16384
```

Do not start Gemma at 65k or 128k context on a 32 GB machine.

---

## Download notes

For large one-time GGUF downloads, `aria2c` is usually faster and more controllable than letting `llama.cpp -hf` download the model.

Use `--dir` for the directory and `-o` for the filename only. If you pass an absolute path to `-o`, `aria2c` can write the model into the wrong place under your current directory.

Example shape:

```bash
aria2c -x 16 -s 16 \
  --dir "$HOME/models" \
  -o gemma-4-31B-it-Q4_K_M.gguf \
  "https://huggingface.co/ggml-org/gemma-4-31B-it-GGUF/resolve/main/gemma-4-31B-it-Q4_K_M.gguf"
```

Use the exact filename from the Hugging Face repo.

---

## Working server commands

### Qwen

```bash
./build/bin/llama-server \
  -m "$HOME/models/Qwen3.6-27B-Q4_K_M.gguf" \
  --host 127.0.0.1 \
  --port 8080 \
  -ngl 999 \
  -c 65536 \
  --flash-attn on \
  --reasoning on \
  --temp 0.6 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0
```

### Gemma 4

```bash
./build/bin/llama-server \
  -m "$HOME/models/gemma-4-31B-it-Q4_K_M.gguf" \
  --host 127.0.0.1 \
  --port 8080 \
  -ngl 999 \
  -c 4096 \
  --flash-attn on \
  --temp 0.6 \
  --top-p 0.95 \
  --top-k 20 \
  --min-p 0.0
```

Healthy startup ends with output like:

```text
model loaded
server is listening on http://127.0.0.1:8080
all slots are idle
```

---

## Daily workflow scripts

This folder includes helper scripts:

- `./start-qwen-local.sh`
- `./stop-qwen-local.sh`
- `./start-gemma4-local.sh`
- `./stop-gemma4-local.sh`
- `./check-qwen-local.sh`

The check script is model-agnostic despite the old name. It checks the server process, port, and `/health` endpoint.

### Start Qwen

```bash
LLAMA_DIR=/path/to/llama.cpp ./start-qwen-local.sh
```

Defaults:

- `MODEL=$HOME/models/Qwen3.6-27B-Q4_K_M.gguf`
- `PORT=8080`
- `CTX_SIZE=65536`

### Start Gemma

```bash
LLAMA_DIR=/path/to/llama.cpp ./start-gemma4-local.sh
```

Defaults:

- `MODEL=$HOME/models/gemma-4-31B-it-Q4_K_M.gguf`
- `PORT=8080`
- `CTX_SIZE=4096`

### Switch from Qwen to Gemma

```bash
./stop-qwen-local.sh
LLAMA_DIR=/path/to/llama.cpp ./start-gemma4-local.sh
```

Then in Pi:

```text
/model
```

Select:

```text
gemma-4-31b-local
```

### Switch from Gemma to Qwen

```bash
./stop-gemma4-local.sh
LLAMA_DIR=/path/to/llama.cpp ./start-qwen-local.sh
```

Then in Pi select:

```text
qwen3.6-27b
```

---

## Pi config

Pi reads custom model providers from:

```text
~/.pi/agent/models.json
```

Use the sanitized example in:

```text
snippets/pi-models-snippet.json
```

Important details:

- Back up `models.json` before editing.
- Merge the providers into your existing file; do not overwrite unrelated providers.
- Both local providers point to the same server URL.
- The selected Pi model should match the model currently loaded in `llama-server`.

Recommended shape:

```json
{
  "providers": {
    "llamacpp-qwen3.6": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "sk-no-key-required",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false,
        "thinkingFormat": "qwen-chat-template"
      },
      "models": [
        {
          "id": "qwen3.6-27b",
          "name": "Qwen 3.6 27B (Local)",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 65536,
          "maxTokens": 16384,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    },
    "llamacpp-gemma4": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "sk-no-key-required",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false
      },
      "models": [
        {
          "id": "gemma-4-31b-local",
          "name": "Gemma 4 31B Q4_K_M (Local)",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": 4096,
          "maxTokens": 2048,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

Pi reloads `models.json` when you open `/model`. In the model list, Qwen should show under `llamacpp-qwen3.6` and Gemma should show under `llamacpp-gemma4`. If a model does not appear, run `/reload` or restart Pi.

---

## Smoke tests

### Server health

```bash
curl -fsS http://127.0.0.1:8080/health
```

Expected:

```json
{"status":"ok"}
```

### Direct chat test

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-test",
    "messages": [
      {"role": "user", "content": "Reply with exactly: local ready"}
    ],
    "temperature": 0,
    "max_tokens": 256
  }' | python3 -m json.tool
```

Gemma may spend initial tokens in reasoning before emitting final content, so very small `max_tokens` values can make it look like it failed. Use at least `256` for the smoke test.

### Pi tool-calling test

After launching Pi with the local model, run:

> Read the contents of my `~/.zshrc` file and tell me what my PATH looks like.

Success means:

- Pi can select the local model.
- Pi can complete a request through `127.0.0.1:8080`.
- Tool calling works.
- No raw tool-call markup leaks into normal text.
- The server does not crash.

---

## What happens if the server is not running

Pi can still show local models in its selector because they exist in `models.json`.

Actual requests fail if `llama-server` is not listening on `127.0.0.1:8080`.

The fix is to start the matching local model before selecting it in Pi.

---

## Final take

Pi plus local `llama.cpp` is viable on an M1 Max with 32 GB RAM for 27B/31B-class Q4 models, but the constraints are real:

- use Metal
- keep only one large local model loaded at a time
- use conservative context for Gemma 4 31B
- prefer `aria2c` for large GGUF downloads
- keep Pi model selection aligned with the currently running server
- benchmark real coding tasks before switching defaults

For now, Qwen remains the safer default for coding because it has validated Pi tool calling and runs faster in a simple local test. Gemma 4 31B is usable and worth testing, especially for answer quality on your own workload.

---

## License

MIT. See [`LICENSE`](LICENSE).
