#!/usr/bin/env bash
# Checks every model in the main.tf catalog against the HuggingFace API:
# that the repo exists (200 = open, 401 = gated, anything else = failure)
# and its safetensors download size. Tool calling cannot be checked
# statically - scripts/test_models.sh verifies it end to end through the
# vLLM OpenAI API.
# Run from anywhere: scripts/check_models.sh

set -euo pipefail

MAIN_TF="$(dirname "$0")/../main.tf"
fail=0

for repo in $(sed -n '/vllm_models = \[/,/^  \]/p' "$MAIN_TF" | grep -oP 'value = "\K[^"]+'); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -m 30 "https://huggingface.co/api/models/$repo")
  case "$code" in
    200) status="open" ;;
    401) status="gated (needs HF token)" ;;
    *) printf '%-55s MISSING (%s)\n' "$repo" "$code"; fail=1; continue ;;
  esac
  size=$(curl -sf -m 30 "https://huggingface.co/api/models/$repo/tree/main?recursive=true" 2>/dev/null \
    | jq '[.[] | select(.path | endswith(".safetensors")) | .size] | add / 1e9 | . * 10 | round / 10' 2>/dev/null || echo '?')
  printf '%-55s %6s GB  %s\n' "$repo" "$size" "$status"
done

exit $fail
