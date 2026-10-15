#!/usr/bin/env bash

# Sets up a local Ollama model for the workspace and configures OpenCode
# to use it. Models live on the pod's LOCAL disk (/tmp, not the NFS home
# volume) - they are re-downloaded on workspace start, which is acceptable
# for now.

set -euo pipefail

MODEL="${ollama_model}"
export OLLAMA_MODELS=/tmp/ollama/models
export PATH="$HOME/.nix-profile/bin:$PATH"

# coder_scripts run concurrently and without .bashrc - wait until the
# nix_setup script has installed the toolset (ollama) before continuing.
for i in $(seq 1 150); do
  command -v ollama >/dev/null 2>&1 && break
  sleep 4
done
command -v ollama >/dev/null 2>&1 || { echo "ERROR: ollama not found - nix toolset not installed (see /tmp/nix_setup.log)"; exit 1; }

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "GPU detected - ollama will use it (with the ollama-cuda build from the llm/ml profiles)."
else
  echo "WARNING: no GPU detected - inference will run on CPU and will be slow for larger models."
  echo "         Consider a GPU workspace with the 'llm' profile (see the Local LLM presets)."
fi

echo "Setting up Ollama with model '$MODEL' (models dir: $OLLAMA_MODELS, local disk)..."

# Start ollama serve if not already running
if ! pgrep -x ollama >/dev/null 2>&1; then
  echo "Starting ollama serve..."
  nohup ollama serve > /tmp/ollama.log 2>&1 &
fi

# Wait for the API to come up
for i in $(seq 1 30); do
  if curl -sf http://localhost:11434/api/version >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -sf http://localhost:11434/api/version >/dev/null 2>&1 || { echo "ERROR: ollama serve did not start (see /tmp/ollama.log)"; exit 1; }

# Pull the model (large download on first start - the local disk is wiped
# when the pod stops)
if ollama list | grep -q "^$MODEL"; then
  echo "Model '$MODEL' already present."
else
  echo "Pulling model '$MODEL' (this may take a while)..."
  ollama pull "$MODEL"
fi

# Prefetch: load the model into memory and keep it resident, so the first
# inference is instant instead of waiting for a cold model load.
echo "Prefetching '$MODEL' into memory (keep_alive=-1)..."
curl -sf http://localhost:11434/api/generate \
  -d "{\"model\": \"$MODEL\", \"keep_alive\": -1}" > /dev/null
echo "Model loaded and pinned in memory."

# Configure OpenCode to use the local model
mkdir -p "$HOME/.config/opencode"
CONFIG="$HOME/.config/opencode/opencode.json"
[ -f "$CONFIG" ] || echo '{}' > "$CONFIG"

jq --arg model "ollama/$MODEL" --arg name "$MODEL" '
  .model = $model
  | .provider.ollama = {
      npm: "@ai-sdk/openai-compatible",
      name: "Ollama (local)",
      options: { baseURL: "http://localhost:11434/v1" },
      models: {}
    }
  | .provider.ollama.models[$name] = {}
' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

echo "Ollama setup complete. OpenCode model: ollama/$MODEL"
