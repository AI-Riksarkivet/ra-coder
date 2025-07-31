#!/bin/bash

# Fix Dagger RBAC Permissions - Issue #23
# Adds namespace-specific pod/exec permissions for Dagger engine communication

set -e

echo "🔧 Fixing Dagger RBAC Permissions (Issue #23)"
echo "=============================================="

# Check if we have admin access
if ! kubectl auth can-i create roles --namespace=dagger; then
    echo "❌ Insufficient permissions to create RBAC resources"
    echo "💡 Run this script with admin kubeconfig:"
    echo "   export KUBECONFIG=/home/coder/coder-templates/kubeconfig"
    echo "   ./fix-dagger-rbac.sh"
    exit 1
fi

echo "✅ Admin permissions confirmed"

# Apply the RBAC fix
echo "📝 Applying namespace-specific RBAC permissions..."
kubectl apply -f dagger-rbac-fix.yaml

echo ""
echo "🔍 Verifying permissions..."

# Check if the service account now has the required permissions
echo "Checking pod/exec permissions in dagger namespace..."
if kubectl auth can-i create pods/exec --namespace=dagger --as=system:serviceaccount:coder:coder-developer; then
    echo "✅ pod/exec permissions granted successfully"
else
    echo "⚠️  pod/exec permissions not yet active (may take a moment)"
fi

# Check pod read permissions
echo "Checking pod read permissions in dagger namespace..."
if kubectl auth can-i get pods --namespace=dagger --as=system:serviceaccount:coder:coder-developer; then
    echo "✅ pod read permissions granted successfully"
else
    echo "⚠️  pod read permissions not yet active"
fi

echo ""
echo "📊 Summary of permissions granted:"
echo "  🎯 Namespace: dagger (limited scope)"
echo "  🔐 Service Account: coder-developer (coder namespace)"
echo "  ⚡ Permissions: pods/exec (create), pods (get/list/watch), pods/log (get/list)"
echo ""
echo "🧪 Test the fix:"
echo "  1. Use regular coder kubeconfig (not admin)"
echo "  2. Run: source .env && dagger version"
echo "  3. Run: timeout 60 dagger call container --from alpine:latest --with-exec echo,\"Fixed!\" stdout"
echo ""
echo "✅ RBAC fix applied successfully!"
echo "📋 Issue #23 should now be resolved"