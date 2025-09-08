#!/usr/bin/env bash

set -euo pipefail

echo "Configuring lakectl.yaml..."

# Read LakeFS secrets from mounted files
LAKECTL_ACCESS_KEY_ID=$(cat /etc/secrets/lakefs/access_key_id)
LAKECTL_SECRET_ACCESS_KEY=$(cat /etc/secrets/lakefs/secret_access_key)

cat > ~/.lakectl.yaml <<LAKECTLCONFIG
credentials:
    access_key_id: "$LAKECTL_ACCESS_KEY_ID"
    secret_access_key: "$LAKECTL_SECRET_ACCESS_KEY"
experimental:
    local:
        posix_permissions:
            enabled: false
local:
    skip_non_regular_files: false
metastore:
    glue:
        catalog_id: ""
    hive:
        db_location_uri: file:/user/hive/warehouse/
        uri: ""
network:
    http2:
        enabled: true
server:
    endpoint_url: http://lakefs.lakefs:80/
    retries:
        enabled: true
        max_attempts: 4
        max_wait_interval: 30s
        min_wait_interval: 200ms
LAKECTLCONFIG

echo "lakectl.yaml configured."
