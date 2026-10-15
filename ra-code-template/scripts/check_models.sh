#!/usr/bin/env bash
# Checks every model in the main.tf catalog against registry.ollama.ai:
# that the tag exists, its download size, and that it supports tool calling
# (RA-CODE is an agent - a model without tools cannot edit files or call MCP
# servers). Ollama derives tool support from the chat template (.Tools) or,
# for newer models, a built-in renderer named in the config blob.
# Run from anywhere: scripts/check_models.sh

set -euo pipefail

REGISTRY=https://registry.ollama.ai/v2/library
MAIN_TF="$(dirname "$0")/../main.tf"
fail=0

for model in $(sed -n '/ollama_models = \[/,/^  \]/p' "$MAIN_TF" | grep -oP 'value = "\K[^"]+'); do
  name=${model%%:*}
  tag=latest
  [[ $model == *:* ]] && tag=${model#*:}

  manifest=$(curl -fsS -m 30 -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
    "$REGISTRY/$name/manifests/$tag" 2>/dev/null || true)
  if ! jq -e .layers >/dev/null 2>&1 <<<"$manifest"; then
    printf '%-28s MISSING\n' "$model"
    fail=1
    continue
  fi

  size=$(jq -r '[.layers[].size] | add / 1e9 | . * 10 | round / 10' <<<"$manifest")
  tools=no
  template=$(jq -r '.layers[] | select(.mediaType | endswith(".template")) | .digest' <<<"$manifest" | head -1)
  if [ -n "$template" ] && curl -fsSL -m 30 "$REGISTRY/$name/blobs/$template" | grep -q '\.Tools'; then
    tools=yes
  else
    config=$(jq -r .config.digest <<<"$manifest")
    renderer=$(curl -fsSL -m 30 "$REGISTRY/$name/blobs/$config" | jq -r '.renderer // empty')
    [ -n "$renderer" ] && tools="yes (renderer $renderer)"
  fi
  [[ $tools == yes* ]] || fail=1

  printf '%-28s %6s GB  tools: %s\n' "$model" "$size" "$tools"
done

exit $fail
