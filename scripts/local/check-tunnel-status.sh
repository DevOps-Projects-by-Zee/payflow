#!/bin/bash
# Quick Cloudflare Tunnel Status Check
# Usage: ./scripts/local/check-tunnel-status.sh

set -e

NAMESPACE="payflow"

echo "🔍 Cloudflare Tunnel Status Check"
echo ""

# Check pod status
echo "Pod Status:"
kubectl get pods -n $NAMESPACE -l app=cloudflare-tunnel 2>/dev/null || echo "❌ No pods found"

echo ""
echo "Recent Logs:"
POD=$(kubectl get pods -n $NAMESPACE -l app=cloudflare-tunnel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD" ]; then
    kubectl logs -n $NAMESPACE $POD --tail=20 2>/dev/null || echo "Could not get logs"
else
    echo "❌ No pod found"
fi

echo ""
echo "Secret Status:"
kubectl get secret cloudflare-tunnel-secret -n $NAMESPACE &> /dev/null && echo "✅ Secret exists" || echo "❌ Secret not found"

echo ""
echo "To fix: ./scripts/local/fix-cloudflare-tunnel.sh"

