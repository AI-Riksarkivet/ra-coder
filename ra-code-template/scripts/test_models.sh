#!/usr/bin/env bash
# End-to-end test of catalog models, run INSIDE a ra-code workspace (pick the
# GPU the models need). For each model it runs the template's real setup
# script with that model (pull, opencode config, GPU load), then tests
# RA-CODE: agent (write + run a file), MCP (Riksarkivet SBL lookup) and, for
# vision models, reading /tmp/vision-test.png (an image showing the text
# "RA-CODE TEST 4217"). The model is unloaded and deleted afterwards.
#
# Render the setup script first, leaving ${model} for this script:
#   sed -e 's|${context_length}|65536|' -e 's|${opencode_version}|<pin>|' \
#       -e "s|\${branding_b64}|$(base64 -w0 scripts/ra-code-branding.tsx)|" \
#       scripts/ollama_setup.sh > setup-template.sh
# Usage: test_models.sh setup-template.sh model...   (results in /tmp/model-tests)
set -uo pipefail
TEMPLATE=$1; shift
API=http://127.0.0.1:11434
OUT=/tmp/model-tests; mkdir -p "$OUT"
export PATH="$HOME/.local/bin:$PATH"

strip() { sed 's/\x1b\[[0-9;]*m//g'; }

for M in "$@"; do
  log="$OUT/$(echo "$M" | tr ':/' '__').log"
  : >"$log"
  t0=$(date +%s)
  # Render the setup script exactly like Coder's templatefile() does.
  sed -e "s|\${model}|$M|g" -e 's|\$\${|${|g' "$TEMPLATE" >/tmp/setup-under-test.sh
  if ! bash /tmp/setup-under-test.sh >>"$log" 2>&1; then
    echo "RESULT $M setup=FAIL ($(grep -m1 ERROR "$log"))"; continue
  fi
  setup_s=$(( $(date +%s) - t0 ))
  gpu=$(curl -sf $API/api/ps | jq -r --arg m "$M" '[.models[] | select(.name == $m or .name == ($m + ":latest"))][0] | "\(.size_vram * 100 / .size | floor)%GPU"')
  caps=$(curl -sf $API/api/show -d "{\"model\":\"$M\"}" | jq -r '.capabilities | join(",")')
  name=$(curl -sf $API/api/show -d "{\"model\":\"$M\"}" >/dev/null && jq -r --arg m "$M" '.provider.ollama.models | keys[] | select(. == $m or . == ($m + ":latest"))' ~/.config/opencode/opencode.json | head -1)
  [ -n "$name" ] || name=$M

  # 1. Agent: write and run a file.
  d=$(mktemp -d); cd "$d"
  timeout 600 ra-code run -m "ollama/$name" "Create a file named check.py that prints the sum of 17 and 25. Then run it with python3 and tell me the printed number." 2>&1 | strip >>"$log"
  agent=FAIL; [ -f check.py ] && [ "$(python3 check.py 2>/dev/null | tr -d '[:space:]')" = 42 ] && agent=ok
  cd /tmp; rm -rf "$d"

  # 2. MCP: Riksarkivet tool call.
  mcpout=$(timeout 600 ra-code run -m "ollama/$name" "Use the riksarkivet search_sbl tool to look up Selma Lagerlöf in Svenskt biografiskt lexikon. Reply with her SBL article id." 2>&1 | strip)
  echo "$mcpout" >>"$log"
  mcp=FAIL; grep -q "riksarkivet_search_sbl" <<<"$mcpout" && grep -qE '[0-9]{4,}' <<<"$(grep -v '⚙' <<<"$mcpout")" && mcp=ok

  # 3. Vision (only for models Ollama reports as vision).
  vision=n/a
  if [[ ,$caps, == *,vision,* ]]; then
    vout=$(timeout 600 ra-code run -m "ollama/$name" "What text is written in this image? Reply with the text only." -f /tmp/vision-test.png 2>&1 | strip)
    echo "$vout" >>"$log"
    vision=FAIL; grep -q 4217 <<<"$vout" && vision=ok
  fi

  echo "RESULT $M setup=ok(${setup_s}s) gpu=$gpu agent=$agent mcp=$mcp vision=$vision caps=$caps total=$(( $(date +%s) - t0 ))s"
  # Free GPU memory and disk for the next model.
  curl -sf $API/api/generate -d "{\"model\":\"$M\",\"keep_alive\":0}" >/dev/null
  curl -sf -X DELETE $API/api/delete -d "{\"model\":\"$M\"}" >/dev/null
done
