#!/usr/bin/env bash
# Waits for the vLLM sidecar, then configures OpenCode to use it.
#
# vLLM runs as a second container in the pod and serves the selected model
# on 127.0.0.1:8000 (OpenAI-compatible). Weights live in the node-local
# emptyDir (/opt/llm/hf), never on the NFS home volume, and are downloaded
# again after every workspace restart - the first start of a big model can
# take 30+ minutes, so the health wait below is generous.

set -euo pipefail

MODEL="${model}"
MODEL_VISION="${model_vision}"
CONTEXT_LENGTH="${context_length}"
OPENCODE_VERSION="${opencode_version}"

API=http://127.0.0.1:8000

# --- GPU check ---
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | paste -sd ';')"
else
  echo "WARNING: no GPU visible from the dev container (the vllm container has it)."
fi

# --- vLLM server (sidecar) ---
if [ -n "$MODEL" ]; then
  echo "Waiting for vLLM to serve $MODEL (first start downloads the weights)..."
  for i in $(seq 1 360); do  # up to 60 min
    curl -sf "$API/health" >/dev/null 2>&1 && break
    [ $((i % 12)) -eq 0 ] && echo "  still loading ($((i * 10 / 60)) min)..."
    sleep 10
  done
  curl -sf "$API/health" >/dev/null 2>&1 || { echo "ERROR: vLLM did not become ready in 60 min - check the vllm container logs (kubectl)"; exit 1; }
  echo "vLLM is up: $(curl -sf "$API/v1/models" | jq -r '.data[0].id')"
else
  echo "No model selected - vLLM sidecar is not running."
fi

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
# RA-CODE: the name users launch it by (the Coder app and the terminal).
# OpenCode hardcodes "OpenCode" as the terminal title, so the launcher turns
# that off and sets its own.
cat >"$HOME/.local/bin/ra-code" <<'WRAPPER'
#!/bin/sh
[ -t 1 ] && printf '\033]0;RA-CODE\007'
OPENCODE_DISABLE_TERMINAL_TITLE=1 exec "$HOME/.local/bin/opencode" "$@"
WRAPPER
chmod 755 "$HOME/.local/bin/ra-code"

# --- OpenCode config ---
# Only the local vLLM provider: the built-in "opencode" provider (its free
# cloud models) is disabled, and so are self-update (the version is pinned
# above) and conversation sharing.
CONFIG_DIR="$HOME/.config/opencode"
CONFIG="$CONFIG_DIR/opencode.json"
mkdir -p "$CONFIG_DIR"
[ -s "$CONFIG" ] || echo '{}' >"$CONFIG"

jq --arg default "$MODEL" '
  ."$schema" = "https://opencode.ai/config.json"
  | .autoupdate = false
  | .share = "disabled"
  | .disabled_providers = ((.disabled_providers // []) + ["opencode"] | unique)
  | .provider.vllm = {
      npm: "@ai-sdk/openai-compatible",
      name: "vLLM (local)",
      options: { baseURL: "http://127.0.0.1:8000/v1" },
      models: (.provider.vllm.models // {})
    }
  | if $default != "" then .model = "vllm/" + $default else del(.model) end
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# Model entry: from /v1/models when the server is up, with image input
# declared when the catalog marks the model as vision (vLLM does not
# advertise modalities, so the flag comes from the template catalog).
write_models() {
  local names
  names=$(curl -sf "$API/v1/models" | jq -r '.data[].id' 2>/dev/null || true)
  [ -n "$names" ] || names="$MODEL"
  jq -n --arg names "$names" '$names | split("\n") | map(select(. != ""))' |
    jq -c 'map({key: ., value: null}) | from_entries' >"$CONFIG_DIR/.models.tmp"
  jq --argjson ctx "$CONTEXT_LENGTH" --argjson vision "$MODEL_VISION" --slurpfile m "$CONFIG_DIR/.models.tmp" '
    .provider.vllm.models = ($m[0] | with_entries(.value = (
      { name: .key, limit: { context: $ctx, output: 8192 } }
      + (if $vision then { attachment: true, modalities: { input: ["text", "image"], output: ["text"] } } else {} end))))
  ' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  rm -f "$CONFIG_DIR/.models.tmp"
}
write_models

# Default MCP servers: Riksarkivet and Archives Portal Europe. Both are public
# (no credentials). A user's "enabled": false survives restarts.
jq '
  def remote($url): { type: "remote", url: $url, oauth: false, timeout: 60000 };
  .mcp.riksarkivet = remote("https://riksarkivet-ra-mcp.hf.space/mcp") + { enabled: (.mcp.riksarkivet.enabled != false) }
  | .mcp.ape = remote("https://riksarkivet-ape-mcp.hf.space/mcp") + { enabled: (.mcp.ape.enabled != false) }
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

# RA-CODE logo on the TUI home screen (a TUI plugin, registered in tui.json
# next to any plugins the user added).
BRANDING="$CONFIG_DIR/ra-code/branding.tsx"
mkdir -p "$CONFIG_DIR/ra-code"
echo "${branding_b64}" | base64 -d >"$BRANDING"
TUI_CONFIG="$CONFIG_DIR/tui.json"
[ -s "$TUI_CONFIG" ] || echo '{}' >"$TUI_CONFIG"
jq --arg spec "file://$BRANDING" '
  ."$schema" = "https://opencode.ai/tui.json"
  | .plugin = (((.plugin // []) - [$spec]) + [$spec])
' "$TUI_CONFIG" >"$TUI_CONFIG.tmp" && mv "$TUI_CONFIG.tmp" "$TUI_CONFIG"

if [ -n "$MODEL" ]; then
  echo "Ready. Run 'ra-code' (default model: vllm/$MODEL)."
else
  echo "Ready. No model: serve one with 'vllm serve <hf-repo>', then pick it in ra-code."
fi
