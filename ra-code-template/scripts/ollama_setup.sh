#!/usr/bin/env bash
# Starts Ollama, configures OpenCode to use it and pulls the selected model.
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
echo "Ollama $(curl -sf "$API/api/version" | jq -r .version) is up."

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

# --- OpenCode config, written before the pull so it is right from the start ---
# Only the local Ollama provider: the built-in "opencode" provider (its free
# cloud models) is disabled, and so are self-update (the version is pinned
# above) and conversation sharing.
CONFIG_DIR="$HOME/.config/opencode"
CONFIG="$CONFIG_DIR/opencode.json"
mkdir -p "$CONFIG_DIR"
[ -s "$CONFIG" ] || echo '{}' >"$CONFIG"

LOCAL_MODELS=$(curl -sf "$API/api/tags" | jq '[.models[].name]')
jq --argjson local "$LOCAL_MODELS" --arg default "$MODEL" --argjson ctx "$CONTEXT_LENGTH" '
  ($local + (if $default != "" then [$default] else [] end) | unique) as $models
  | ."$schema" = "https://opencode.ai/config.json"
  | .autoupdate = false
  | .share = "disabled"
  | .disabled_providers = ((.disabled_providers // []) + ["opencode"] | unique)
  | .provider.ollama = {
      npm: "@ai-sdk/openai-compatible",
      name: "Ollama (local)",
      options: { baseURL: "http://127.0.0.1:11434/v1" },
      models: (reduce $models[] as $m ({}; .[$m] = { name: $m, limit: { context: $ctx, output: 8192 } }))
    }
  | if $default != "" then .model = "ollama/" + $default else del(.model) end
' "$CONFIG" >"$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

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

# --- Pull and preload the selected model ---
if [ -n "$MODEL" ]; then
  echo "Pulling $MODEL (re-downloaded on every workspace start)..."
  # The API stream instead of `ollama pull`, whose spinner floods the log.
  curl -sfN "$API/api/pull" -d "{\"model\": \"$MODEL\"}" |
    jq -rn --unbuffered '
      foreach inputs as $e ({};
        .line = (if $e.error then "ERROR: " + $e.error
                 elif $e.total and $e.completed then "\($e.status) \($e.completed * 100 / $e.total | floor)%"
                 else $e.status end)
        | .new = (.line != .last) | .last = .line;
        select(.new) | .line)' |
    tee "$LLM_DIR/pull.log" | grep --line-buffered -v '%$' || true
  grep -q '^success$' "$LLM_DIR/pull.log" || { echo "ERROR: pulling $MODEL failed"; exit 1; }

  echo "Loading $MODEL into GPU memory..."
  curl -sf "$API/api/generate" -d "{\"model\": \"$MODEL\", \"keep_alive\": \"30m\"}" >/dev/null
  curl -sf "$API/api/ps" | jq -r '.models[] | "Loaded \(.name): \(.size_vram * 100 / .size | floor)% on GPU, context \(.context_length)"'
fi

if [ -n "$MODEL" ]; then
  echo "Ready. Run 'ra-code' (default model: ollama/$MODEL)."
else
  echo "Ready. No model selected: 'ollama pull <model>', then pick it in ra-code."
fi
