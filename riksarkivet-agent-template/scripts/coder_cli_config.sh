#!/usr/bin/env bash

set -euo pipefail

echo "Configuring Coder CLI..."
mkdir -p /home/coder/.config/coderv2

cat > /home/coder/.config/coderv2/config.yaml <<CODERCONFIG
url: "${coder_url}"
CODERCONFIG

# Set proper ownership
chown -R coder:coder /home/coder/.config/coderv2

echo "Coder CLI configuration completed."
