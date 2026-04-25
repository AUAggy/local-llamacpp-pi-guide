# Running Pi with llama.cpp and Qwen 3.6-27B on an M1 Max with 32 GB RAM

This is a practical guide for running Pi against a local `llama.cpp` server on Apple Silicon.

It was validated on an M1 Max with 32 GB unified memory using `Qwen3.6-27B-Q4_K_M.gguf`.

This folder is self-contained. You can copy it into a new repo or initialize it directly as its own Git repository.

## Why this setup

If you want a local model that is good enough for real coding sessions, a 27B-class Qwen model is a reasonable target on a 32 GB Apple Silicon machine.

It is not roomy, and it is not free, but it works.

The main constraints are memory pressure, model download size, and whether tool calling survives local inference. In this configuration, all three were workable.

---

## What worked

- `llama.cpp` built from source with Metal enabled
- `Qwen3.6-27B-Q4_K_M.gguf` loaded successfully
- Pi connected to the local OpenAI-compatible endpoint
- model selection worked inside Pi
- tool calling worked in a smoke test
- thinking mode was enabled without breaking the tool loop

That last point matters. There is a known issue in `llama.cpp` where some Qwen configurations emit raw XML tool calls inside the thinking block. In this run, the smoke test succeeded.

---

## Why not use `brew install llama.cpp`

On Apple Silicon, Homebrew is convenient but not the safest option if you care about Metal acceleration and reproducibility.

Building from source makes the backend choice explicit and avoids ambiguity about how `ggml` was built.

---

## Build notes that mattered

### 1. Metal build

Use CMake with Metal enabled:

```bash
cmake -B build \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DLLAMA_BUILD_TESTS=OFF
```

### 2. OpenSSL path conflict on macOS

A surprising build failure came from old OpenSSL headers in `/usr/local/include/openssl` shadowing the current OpenSSL 3 install.

The fix was to force the compiler to prefer the Homebrew OpenSSL 3 include and library paths:

```bash
export CFLAGS="-I/opt/homebrew/opt/openssl@3/include"
export CXXFLAGS="-I/opt/homebrew/opt/openssl@3/include"
export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib"
```

This was enough to get the build through without deleting older headers from `/usr/local`.

---

## Model choice

The model used here was:

```text
Qwen3.6-27B-Q4_K_M.gguf
```

Why this quant:

- good quality for the memory budget
- small enough to fit on a 32 GB machine
- still capable enough for coding tasks

Why not the larger MoE variant:

The 35B-A3B model only activates a smaller subset of parameters per forward pass, but the full weight matrix still has to be loaded. On a 32 GB machine that leaves much less margin for context and the rest of the system.

---

## Download notes

The standard Hugging Face CLI works, but for a file this large, `aria2c` may be much faster.

Example:

```bash
aria2c -x 16 -s 16 \
  --dir "$HOME/models" \
  -o Qwen3.6-27B-Q4_K_M.gguf \
  "https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/resolve/main/Qwen3.6-27B-Q4_K_M.gguf"
```

Important detail:

Use `--dir` for the directory and `-o` for the filename only.

If you pass an absolute path to `-o`, `aria2c` treats it like a relative filename and can write the model into the wrong place under your current directory.

---

## Working `llama-server` command

This command worked:

```bash
./build/bin/llama-server \
  -m "$HOME/models/Qwen3.6-27B-Q4_K_M.gguf" \
  --host 127.0.0.1 \
  --port 8080 \
  -ngl 999 \
  -c 65536 \
  --flash-attn on \
  --chat-template-kwargs '{"enable_thinking":true}'
```

A few details mattered here:

- `-c 65536`: sets the actual server context size
- `--flash-attn on`: some builds require an explicit value, not a bare flag
- `--chat-template-kwargs '{"enable_thinking":true}'`: turns on Qwen reasoning mode through the chat template

A healthy startup ends with output like:

```text
main: model loaded
main: server is listening on http://127.0.0.1:8080
srv  update_slots: all slots are idle
```

---

## Pi config

Pi can be pointed at the local `llama.cpp` server by adding a custom provider block to:

```text
~/.pi/agent/models.json
```

Use the sanitized example in:

```text
snippets/pi-models-snippet.json
```

Important detail:

If Pi is already in use, back up the existing `models.json` first and merge this provider in. Do not overwrite your whole config just to add one local model.

---

## Daily workflow

This folder includes three helper scripts:

- `./start-qwen-local.sh`
- `./check-qwen-local.sh`
- `./stop-qwen-local.sh`

### Start

```bash
./start-qwen-local.sh
```

By default, the script expects:

- `LLAMA_DIR=/path/to/llama.cpp`
- `MODEL=$HOME/models/Qwen3.6-27B-Q4_K_M.gguf`

You can override either one with environment variables:

```bash
LLAMA_DIR=/path/to/llama.cpp MODEL=$HOME/models/Qwen3.6-27B-Q4_K_M.gguf ./start-qwen-local.sh
```

### Check

```bash
./check-qwen-local.sh
```

### Stop

```bash
./stop-qwen-local.sh
```

---

## Smoke test

After launching Pi with the local model, run a tool-calling test immediately.

Example prompt:

> Read the contents of my `~/.zshrc` file and tell me what my PATH looks like.

In this setup, the smoke test passed.

That means:

- tool calling worked
- no raw XML was emitted
- the agent loop stayed intact

---

## What happens if the server is not running

Pi can still show the model in its selector because the model exists in `models.json`.

But actual requests fail if `llama-server` is not listening on `127.0.0.1:8080`.

In practice, that means model selection succeeds and inference fails.

The simplest fix is to keep a start script next to your notes.

---

## Should `llama-server` stay running

Idle `llama-server` does not burn much CPU, but it does keep the model loaded in memory.

On a 32 GB Apple Silicon machine, that means a meaningful chunk of unified memory stays reserved.

For an active session, leave it running.

When you are done for a while, stop it.

---

## Final take

If your question is whether Pi plus `llama.cpp` plus Qwen 3.6 is viable on an M1 Max with 32 GB RAM, the answer is yes.

Not in theory. In practice.

The setup needed a few real-world fixes:

- explicit OpenSSL include and library paths
- explicit `--flash-attn on`
- care around output paths when using `aria2c`
- a merged Pi config instead of a replaced one

Once those were handled, the system worked.
