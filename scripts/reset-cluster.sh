#!/bin/bash
# ============================================
# PayFlow MicroK8s Cluster Reset Script
# ============================================
# Purpose: Clean slate - delete all PayFlow resources
# Usage: ./scripts/reset-cluster.sh

set -e  # Exit on error

export KUBECONFIG=~/.kube/microk8s-config

echo "🧹 PayFlow Cluster Reset"
echo "============================================"
echo ""

# Delete namespaces (this deletes everything in them)
echo "📦 Deleting namespaces..."
kubectl delete namespace payflow --ignore-not-found=true --timeout=60s 2>/dev/null || true
kubectl delete namespace monitoring --ignore-not-found=true --timeout=60s 2>/dev/null || true

# Delete any orphaned PVCs
echo "💾 Cleaning up persistent volumes..."
kubectl delete pvc --all -n payflow --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc --all -n monitoring --ignore-not-found=true 2>/dev/null || true

# Wait for cleanup
echo "⏳ Waiting for resources to terminate..."
sleep 15

# Verify cleanup
echo ""
echo "✅ Checking remaining resources..."
kubectl get all -A 2>/dev/null | grep -E "payflow|monitoring" || echo "   All clean!"

echo ""
echo "🎉 Cluster reset complete!"
echo ""
echo "Next step: Rebuild Docker images and redeploy"
echo "  Run: ./scripts/build-and-deploy.sh"

