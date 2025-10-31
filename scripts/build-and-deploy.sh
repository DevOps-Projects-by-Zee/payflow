#!/bin/bash
# ============================================
# PayFlow Build and Deploy Script
# ============================================
# Purpose: Build Docker images in Colima and deploy to MicroK8s
# Usage: ./scripts/build-and-deploy.sh

set -e  # Exit on error

export KUBECONFIG=~/.kube/microk8s-config

echo "🚀 PayFlow Build and Deploy"
echo "============================================"
echo ""

# Check if Colima is running
echo "🔍 Checking Colima..."
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Docker/Colima is not running!"
    echo "   Start Colima: colima start"
    exit 1
fi
echo "✅ Colima is running"
echo ""

# Build Docker images
echo "🔨 Building Docker images..."
echo ""

# Frontend (optimized nginx build)
echo "📦 Building frontend..."
cd services/frontend
docker build -t payflow/frontend:latest --build-arg REACT_APP_API_URL=https://api.payflow.local/api .
cd ../..

# API Gateway
echo "📦 Building api-gateway..."
cd services/api-gateway
docker build -t payflow/api-gateway:latest .
cd ../..

# Auth Service
echo "📦 Building auth-service..."
cd services/auth-service
docker build -t payflow/auth-service:latest .
cd ../..

# Wallet Service
echo "📦 Building wallet-service..."
cd services/wallet-service
docker build -t payflow/wallet-service:latest .
cd ../..

# Transaction Service
echo "📦 Building transaction-service..."
cd services/transaction-service
docker build -t payflow/transaction-service:latest .
cd ../..

# Notification Service
echo "📦 Building notification-service..."
cd services/notification-service
docker build -t payflow/notification-service:latest .
cd ../..

echo ""
echo "✅ All images built!"
echo ""

# Save images
echo "💾 Saving images to tar..."
docker save payflow/frontend:latest \
            payflow/api-gateway:latest \
            payflow/auth-service:latest \
            payflow/wallet-service:latest \
            payflow/transaction-service:latest \
            payflow/notification-service:latest \
            -o payflow-images.tar

echo "✅ Images saved to payflow-images.tar"
echo ""

# Load images to MicroK8s
echo "📥 Loading images to MicroK8s..."
multipass transfer payflow-images.tar microk8s-vm:/tmp/payflow-images.tar
multipass exec microk8s-vm -- bash -c "microk8s ctr image import /tmp/payflow-images.tar && rm /tmp/payflow-images.tar"
rm payflow-images.tar

echo "✅ Images loaded to MicroK8s"
echo ""

# Create namespaces
echo "📦 Creating namespaces..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring-namespace.yaml

echo ""

# Deploy infrastructure first
echo "🏗️  Deploying infrastructure..."
kubectl apply -f k8s/secrets/db-secrets.yaml
kubectl apply -f k8s/configmaps/app-config.yaml
kubectl apply -f k8s/statefulsets/postgres.yaml
kubectl apply -f k8s/deployments/rabbitmq.yaml
kubectl apply -f k8s/deployments/redis.yaml

# Wait for databases
echo "⏳ Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=120s || true

echo "⏳ Waiting for RabbitMQ..."
kubectl wait --for=condition=ready pod -l app=rabbitmq -n payflow --timeout=120s || true

echo ""

# Deploy services
echo "🔧 Deploying application services..."
kubectl apply -f k8s/deployments/api-gateway.yaml
kubectl apply -f k8s/deployments/auth-service.yaml
kubectl apply -f k8s/deployments/wallet-service.yaml
kubectl apply -f k8s/deployments/transaction-service.yaml
kubectl apply -f k8s/deployments/notification-service.yaml
kubectl apply -f k8s/deployments/frontend.yaml

echo ""

# Deploy cron jobs
echo "⏰ Deploying cron jobs..."
kubectl apply -f k8s/jobs/db-migration.yaml
kubectl apply -f k8s/jobs/transaction-timeout.yaml

echo ""

# Deploy ingress
echo "🌐 Deploying ingress..."
kubectl apply -f k8s/ingress/http-ingress.yaml

echo ""

# Deploy monitoring (optional)
echo "📊 Deploying monitoring..."
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
kubectl apply -f k8s/monitoring/grafana-datasources.yml
kubectl apply -f k8s/monitoring/grafana-dashboard-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
kubectl apply -f k8s/ingress/monitoring-ingress.yaml

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Access Points:"
echo "  API Gateway: http://10.1.254.102"
echo "  Grafana: http://10.1.254.101"
echo "  Prometheus: http://10.1.254.100"
echo ""
echo "📋 Check status:"
echo "  kubectl get pods -n payflow"
echo "  kubectl get svc -A"
echo ""

