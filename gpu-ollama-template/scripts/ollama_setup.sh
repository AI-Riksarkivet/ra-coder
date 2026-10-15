#!/usr/bin/env bash
# Starts Ollama, pulls the selected model and configures OpenCode to use it.
#
# The ollama binary and its CUDA libraries are copied into the node-local
# emptyDir (/opt/llm) by the init container, and models are stored there as
# well. Nothing model-related touches the NFS home volume: the model is
# downloaded again after every workspace restart.

set -euo pipefail

MODEL="${model}"
CONTEXT_LENGTH="${context_length}"
OPENCODE_VERSION="${opencode_version}"

LLM_DIR=/opt/llm
OLLAMA="$LLM_DIR/ollama/bin/ollama"
API=http://127.0.0.1:11434

[ -x "$OLLAMA" ] || { echo "ERROR: $OLLAMA missing - the ollama-install init container did not run"; exit 1; }

# --- GPU check ---
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | paste -sd ';')"
else
  echo "WARNING: no GPU visible - Ollama will run models on the CPU."
fi

# --- Ollama server ---
if ! curl -sf "$API/api/version" >/dev/null 2>&1; then
  echo "Starting ollama serve (models in $OLLAMA_MODELS, context $CONTEXT_LENGTH)..."
  nohup "$OLLAMA" serve >"$LLM_DIR/serve.log" 2>&1 &
fi
for _ in $(seq 1 60); do
  curl -sf "$API/api/version" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf "$API/api/version" >/dev/null 2>&1 || { echo "ERROR: ollama serve did not start, see $LLM_DIR/serve.log"; exit 1; }
echo "Ollama $("$OLLAMA" --version 2>/dev/null | awk '{print $NF}') is up."

# --- OpenCode (pinned release, kept in ~/.local/bin across restarts) ---
case "$(uname -m)" in
  x86_64) OC_ARCH=x64 ;;
  aarch64 | arm64) OC_ARCH=arm64 ;;
  *) echo "ERROR: unsupported architecture $(uname -m)"; exit 1 ;;
esac
mkdir -p "$HOME/.local/bin"
if [ "$("$HOME/.local/bin/opencode" --version 2>/dev/null || true)" != "$OPENCODE_VERSION" ]; then
  echo "Installing opencode $OPENCODE_VERSION..."
  TMP=$(mktemp -d)
  curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v$OPENCODE_VERSION/opencode-linux-$OC_ARCH.tar.gz" | tar -xzf - -C "$TMP"
  install -m 755 "$TMP/opencode" "$HOME/.local/bin/opencode"
  rm -rf "$TMP"
fi

# --- Pull and preload the selected model ---
if [ -n "$MODEL" ]; then
  echo "Pulling $MODEL (re-downloaded on every workspace start)..."
  "$OLLAMA" pull "$MODEL"
  echo "Loading $MODEL into memory..."
  curl -sf "$API/api/generate" -d "{\"model\": \"$MODEL\", \"keep_alive\": \"30m\"}" >/dev/null
  "$OLLAMA" ps
fi

# --- OpenCode config: every locally available model, selected one as default ---
CONFIG_DIR="$HOME/.config/opencode"
CONFIG="$CONFIG_DIR/opencode.json"
mkdir -p "$CONFIG_DIR"
[ -s "$CONFIG" ] || echo '{}' >"$CONFIG"

MODELS_JSON=$(curl -sf "$API/api/tags" | jq '[.models[].name]')
jq --argjson models "$MODELS_JSON" --arg default "$MODEL" --argjson ctx "$CONTEXT_LENGTH" '
  ."$schema" = "https://opencode.ai/config.json"
  | .provider.ollama = {
      npm: "@ai-sdk/openai-compatible",
      name: "Ollama (local)",
      options: { baseURL: "http://127.0.0.1:11434/v1" },
      models: (reduce $models[] as $m ({}; .[$m] = { name: $m, limit: { context: $ctx, output: 8192 } }))
    }
  | if $default != "" then .model = "ollama/" + $default else . end
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

echo "Ready. Run 'opencode' (default model: ollama/$${MODEL:-none})."
