#!/bin/bash
# ============================================
# scripts/deploy-k8s.sh - Kubernetes Deployment
# ============================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "☸️  PayFlow Kubernetes Deployment"
echo "=================================="
echo ""

# Check kubectl
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required${NC}" >&2; exit 1; }

# Get cluster info
echo "📋 Cluster Info:"
kubectl cluster-info
echo ""

# Deploy namespace
echo "🏗️  Creating namespace..."
kubectl apply -f k8s/namespace.yaml

# Deploy ConfigMaps
echo "⚙️  Deploying ConfigMaps..."
kubectl apply -f k8s/configmaps/

# Deploy Secrets
echo "🔐 Deploying Secrets..."
kubectl apply -f k8s/secrets/

# Deploy StatefulSets (databases)
echo "🗄️  Deploying StatefulSets..."
kubectl apply -f k8s/statefulsets/

echo "⏳ Waiting for databases to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n payflow --timeout=300s

# Deploy Services
echo "🌐 Deploying Services..."
kubectl apply -f k8s/services/

# Deploy Deployments
echo "🚀 Deploying Applications..."
kubectl apply -f k8s/deployments/

echo "⏳ Waiting for applications to be ready..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n payflow --timeout=300s

# Deploy Ingress
echo "🌍 Deploying Ingress..."
kubectl apply -f k8s/ingress/

# Deploy Monitoring
echo "📊 Deploying Monitoring Stack..."
kubectl apply -f k8s/monitoring/

# Show status
echo ""
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo ""
echo "📊 Deployment Status:"
kubectl get pods -n payflow
echo ""
kubectl get services -n payflow
echo ""
kubectl get ingress -n payflow
echo ""

# Get LoadBalancer IP
echo "📍 Access Points:"
GATEWAY_IP=$(kubectl get svc api-gateway -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$GATEWAY_IP" ]; then
    echo "   API Gateway: http://$GATEWAY_IP"
else
    echo "   API Gateway: http://$(kubectl get svc api-gateway -n payflow -o jsonpath='{.spec.clusterIP}')"
fi
