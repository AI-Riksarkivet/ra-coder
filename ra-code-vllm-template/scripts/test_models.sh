#!/usr/bin/env bash
# End-to-end test of the model currently served by the vLLM sidecar:
#   1. tool calling through the OpenAI API (the catalog's parser works)
#   2. vision (if $VISION=true): read digits off a generated image
#   3. agent path: ra-code writes and runs a Python file
#   4. MCP path: ra-code uses the Riksarkivet MCP (SBL lookup)
# Appends one JSON line per model to ~/vllm-tests/results.jsonl.
# Usage: VISION=true bash test_models.sh

set -uo pipefail

API=http://127.0.0.1:8000
MODEL=$(curl -sf "$API/v1/models" | jq -r '.data[0].id')
VISION=${VISION:-false}
OUT=~/vllm-tests
mkdir -p "$OUT"
echo "== testing $MODEL (vision=$VISION) =="

# --- 1. tool calling ---
TOOLS='[{"type":"function","function":{"name":"get_inventory","description":"Return inventory count for a product.","parameters":{"type":"object","properties":{"product":{"type":"string","enum":["keyboard","monitor"]}},"required":["product"]}}}]'
jq -nc --arg m "$MODEL" --argjson t "$TOOLS" \
  '{model:$m, messages:[{role:"user",content:"How many keyboards are in stock? Use the get_inventory tool."}], tools:$t, max_tokens:512}' \
  > /tmp/vllm_tool_probe.json
tool_resp=$(curl -sf "$API/v1/chat/completions" -H 'Content-Type: application/json' -d @/tmp/vllm_tool_probe.json |
  jq -c '.choices[0].message as $m | [($m.tool_calls // [] | length), ($m.tool_calls[0].function.name // "none")]' 2>/dev/null || echo '["error"]')
tool_ok=false
[ "$tool_resp" = '[1,"get_inventory"]' ] && tool_ok=true
echo "tools: $tool_resp -> $tool_ok"

# --- 2. vision ---
vision_ok=null
if [ "$VISION" = true ]; then
  ~/vllm-tests/venv/bin/python - <<'PY'
from PIL import Image, ImageDraw, ImageFont
im = Image.new('RGB', (420, 140), 'white')
ImageDraw.Draw(im).text((20, 50), 'RA-CODE TEST 42 17', fill='black', font=ImageFont.load_default(28))
im.save('/tmp/vllm_vision_test.png')
PY
  b64=$(base64 -w0 /tmp/vllm_vision_test.png)
  vresp=$(curl -sf "$API/v1/chat/completions" -H 'Content-Type: application/json' -d "{
    \"model\": \"$MODEL\",
    \"messages\": [{\"role\":\"user\",\"content\":[
      {\"type\":\"text\",\"text\":\"What four digits are shown after RA-CODE TEST? Answer with only the digits.\"},
      {\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,$b64\"}}]}],
    \"max_tokens\": 1024
  }" | jq -r '.choices[0].message.content' 2>/dev/null || echo 'error')
  vision_ok=false
  grep -q '4217' <<<"$vresp" && vision_ok=true
  echo "vision: '$vresp' -> $vision_ok"
fi

# --- 3. agent path (one retry: the first opencode run after engine start
# can race CUDA graph capture and fail spuriously) ---
agent_ok=false
for attempt in 1 2; do
  rm -rf /tmp/vllm_agent_test && mkdir -p /tmp/vllm_agent_test && cd /tmp/vllm_agent_test
  agent_out=$(timeout 420 ~/.local/bin/opencode run 'Write a Python file fib.py that prints the first 10 Fibonacci numbers, then run it with python3.' 2>&1 | tail -20)
  if [ -f fib.py ] && python3 fib.py | grep -q '34'; then
    agent_ok=true
    break
  fi
  echo "agent: attempt $attempt failed, retrying in 30s..."
  sleep 30
done
echo "agent: $agent_ok"

# --- 4. MCP path ---
mcp_out=$(timeout 420 ~/.local/bin/opencode run 'Use the riksarkivet MCP server to search Svenskt biografiskt lexikon for the article about Gustav Vasa. What year did his reign start?' 2>&1 | tail -20)
mcp_ok=false
grep -qi 'riksarkivet_' <<<"$mcp_out" && mcp_ok=true
echo "mcp: $mcp_ok"

jq -nc --arg m "$MODEL" --argjson tools "$tool_ok" --argjson vision "$vision_ok" \
       --argjson agent "$agent_ok" --argjson mcp "$mcp_ok" --arg ts "$(date -Is)" \
  '{model: $m, tools: $tools, vision: $vision, agent: $agent, mcp: $mcp, ts: $ts}' >> "$OUT/results.jsonl"
tail -1 "$OUT/results.jsonl"
