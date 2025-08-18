#!/bin/bash
set -euo pipefail

# Configuration
NAMESPACE="${NAMESPACE:-coder}"  # Change this to your Coder namespace
SERVICE_ACCOUNT="coder-developer"
SECRET_NAME="coder-developer-token"
KUBECONFIG_FILE="coder-developer-kubeconfig"

echo "Creating kubeconfig for Coder developers..."

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_CA=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ca\.crt}')

# Get service account token
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.token}' | base64 -d)

# Create kubeconfig file
cat > "$KUBECONFIG_FILE" <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $CLUSTER_CA
    server: $CLUSTER_SERVER
  name: $CLUSTER_NAME
contexts:
- context:
    cluster: $CLUSTER_NAME
    user: $SERVICE_ACCOUNT
    namespace: $NAMESPACE
  name: $SERVICE_ACCOUNT@$CLUSTER_NAME
current-context: $SERVICE_ACCOUNT@$CLUSTER_NAME
users:
- name: $SERVICE_ACCOUNT
  user:
    token: $TOKEN
EOF

echo "Kubeconfig created: $KUBECONFIG_FILE"
echo "You can test it with: kubectl --kubeconfig=$KUBECONFIG_FILE get pods"