#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Continue Local Assistant configuration..."
mkdir -p /home/coder/.continue

# Create Continue config file
cat > /home/coder/.continue/config.yaml <<'CONTINUECONFIG'
name: Local Assistant
version: 1.0.0
schema: v1
models:
  # VLLM OpenHands Model
  - name: OpenHands Local (vLLM)
    provider: vllm
    model: all-hands/openhands-lm-32b-v0.1
    apiBase: http://llm-service.models:8000/v1
    roles:
      - chat
context:
  - provider: code
  - provider: docs
  - provider: diff
  - provider: terminal
  - provider: problems
  - provider: folder
  - provider: codebase
CONTINUECONFIG

echo "Continue configuration completed."

# -------------------------------------------------------------------


echo "Setting up Aider configuration..."

cat > ~/.aider.conf.yml <<'AIDERCONFIG'
# /home/coder/.aider.conf.yml

openai-api-base: http://llm-service.models:8000/v1

# Add 'openai/' prefix to tell litellm how to treat the model
model: openai/all-hands/openhands-lm-32b-v0.1

openai-api-key: nokey # Assuming no key is needed for this local model

# Other global defaults...
AIDERCONFIG

echo "Aider config created at /home/coder/.aider.conf.yml"
