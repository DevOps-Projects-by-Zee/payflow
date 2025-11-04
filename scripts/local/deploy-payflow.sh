#!/bin/bash
# ============================================
# PayFlow Complete Deployment Script
# ============================================
# Purpose: One script to deploy everything
# - MicroK8s setup & configuration
# - Docker image builds
# - Kubernetes deployments
# - Monitoring stack (Prometheus, Grafana, alert rules)
# - ArgoCD (GitOps)
# - Cloudflare Tunnel
#
# Usage: ./scripts/deploy-payflow.sh
# ============================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VM_NAME="microk8s-vm"
KUBECONFIG_PATH="$HOME/.kube/microk8s-config"
METALLB_IP_RANGE="10.1.254.100-10.1.254.150"

# Services to build
SERVICES=(
  "api-gateway"
  "auth-service"
  "wallet-service"
  "transaction-service"
  "notification-service"
  "frontend"
)

log_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_section() {
  echo -e "\n${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}\n"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed. Please install it first."
    exit 1
  fi
}

# ============================================
# Step 1: Prerequisites Check
# ============================================
log_section "Step 1: Checking Prerequisites"

check_command multipass
check_command docker
check_command kubectl
check_command jq

log_success "All prerequisites installed"

# ============================================
# Step 2: MicroK8s VM Setup
# ============================================
log_section "Step 2: Setting Up MicroK8s VM"

if multipass list | grep -q "$VM_NAME"; then
  log_info "MicroK8s VM already exists, checking status..."
  if multipass list | grep "$VM_NAME" | grep -q Running; then
    log_success "MicroK8s VM is running"
  else
    log_info "Starting MicroK8s VM..."
    multipass start "$VM_NAME"
  fi
else
  log_info "Creating new MicroK8s VM (this takes 2-3 minutes)..."
  multipass launch --name "$VM_NAME" --mem 4G --disk 20G --cpus 2
  log_success "MicroK8s VM created"
fi

# Check if MicroK8s is installed in VM
if ! multipass exec "$VM_NAME" -- command -v microk8s &> /dev/null; then
  log_info "Installing MicroK8s in VM..."
  multipass exec "$VM_NAME" -- sudo snap install microk8s --classic --channel=1.28/stable
  multipass exec "$VM_NAME" -- sudo usermod -a -G microk8s ubuntu
  multipass exec "$VM_NAME" -- sudo chown -R ubuntu ~/.kube
  log_success "MicroK8s installed"
else
  log_info "MicroK8s already installed in VM"
fi

# Get kubectl config
log_info "Configuring kubectl access..."
multipass exec "$VM_NAME" -- microk8s config > "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"
log_success "kubectl configured"

# Verify MicroK8s is running
log_info "Verifying MicroK8s status..."
if multipass exec "$VM_NAME" -- microk8s status --wait-ready &> /dev/null; then
  log_success "MicroK8s is running"
else
  log_error "MicroK8s is not running. Please check logs."
  exit 1
fi

# ============================================
# Step 3: Enable MicroK8s Addons
# ============================================
log_section "Step 3: Enabling MicroK8s Addons"

# Function to enable addon if not already enabled
enable_addon() {
  local addon=$1
  local config=$2
  
  log_info "Checking $addon addon..."
  if multipass exec "$VM_NAME" -- microk8s status | grep -q "$addon.*enabled"; then
    log_success "$addon already enabled"
  else
    log_info "Enabling $addon..."
    if [ -n "$config" ]; then
      echo "$config" | multipass exec "$VM_NAME" -- microk8s enable "$addon"
    else
      multipass exec "$VM_NAME" -- microk8s enable "$addon"
    fi
    sleep 5
    log_success "$addon enabled"
  fi
}

# Get VM IP for MetalLB range
VM_IP=$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}' | cut -d'.' -f1-3)
if [ -n "$VM_IP" ]; then
  METALLB_RANGE="${VM_IP}.100-${VM_IP}.150"
else
  METALLB_RANGE="$METALLB_IP_RANGE"
fi

enable_addon "dns"
enable_addon "ingress"
enable_addon "storage"
log_info "Enabling MetalLB with IP range: $METALLB_RANGE"
echo "$METALLB_RANGE" | multipass exec "$VM_NAME" -- microk8s enable metallb
sleep 5
enable_addon "registry"
enable_addon "cert-manager"

log_success "All addons enabled"

# ============================================
# Step 4: Build Docker Images
# ============================================
log_section "Step 4: Building Docker Images"

cd "$PROJECT_DIR"

# Check if Colima/Docker is running
if ! docker info &> /dev/null; then
  log_warning "Docker not running, attempting to start Colima..."
  colima start || log_error "Failed to start Docker. Please start Colima manually."
fi

# Build all service images
for service in "${SERVICES[@]}"; do
  log_info "Building $service image..."
  docker build -t "payflow/${service}:latest" "services/${service}"
  log_success "$service image built"
done

# ============================================
# Step 5: Load Images into MicroK8s
# ============================================
log_section "Step 5: Loading Images into MicroK8s"

for service in "${SERVICES[@]}"; do
  log_info "Loading $service image into MicroK8s..."
  docker save "payflow/${service}:latest" | multipass exec "$VM_NAME" -- docker load
  log_success "$service image loaded"
done

# ============================================
# Step 6: Deploy Kubernetes Resources
# ============================================
log_section "Step 6: Deploying Kubernetes Resources"

# Create namespaces
log_info "Creating namespaces..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/monitoring-namespace.yaml
kubectl apply -f k8s/argocd-namespace.yaml
log_success "Namespaces created"

# Deploy secrets
log_info "Deploying secrets..."
kubectl apply -f k8s/secrets/db-secrets.yaml

# Check if Cloudflare tunnel secret exists
if [ -f "k8s/secrets/cloudflare-tunnel-secret.yaml" ]; then
  log_info "Deploying Cloudflare tunnel secret..."
  kubectl apply -f k8s/secrets/cloudflare-tunnel-secret.yaml
else
  log_warning "Cloudflare tunnel secret not found. Please create k8s/secrets/cloudflare-tunnel-secret.yaml"
fi

# Deploy configmaps
log_info "Deploying configmaps..."
kubectl apply -f k8s/configmaps/app-config.yaml
log_success "Configmaps deployed"

# Deploy infrastructure
log_info "Deploying infrastructure (PostgreSQL, Redis, RabbitMQ)..."
kubectl apply -f k8s/statefulsets/postgres.yaml
kubectl apply -f k8s/deployments/redis.yaml
kubectl apply -f k8s/deployments/rabbitmq.yaml

# Wait for PostgreSQL to be ready
log_info "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s || {
  log_error "PostgreSQL failed to start"
  exit 1
}
log_success "Infrastructure deployed"

# Deploy application services
log_info "Deploying application services..."
kubectl apply -f k8s/deployments/api-gateway.yaml
kubectl apply -f k8s/deployments/auth-service.yaml
kubectl apply -f k8s/deployments/wallet-service.yaml
kubectl apply -f k8s/deployments/transaction-service.yaml
kubectl apply -f k8s/deployments/notification-service.yaml
kubectl apply -f k8s/deployments/frontend.yaml
log_success "Application services deployed"

# Deploy jobs
log_info "Deploying jobs..."
kubectl apply -f k8s/jobs/db-migration.yaml
kubectl apply -f k8s/jobs/transaction-timeout.yaml
log_success "Jobs deployed"

# Wait for all pods to be ready
log_info "Waiting for all pods to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -n payflow --all --timeout=600s || {
  log_warning "Some pods may still be starting. Check status with: kubectl get pods -n payflow"
}

# ============================================
# Step 7: Deploy Monitoring Stack
# ============================================
log_section "Step 7: Deploying Monitoring Stack"

log_info "Deploying Prometheus configuration..."
kubectl apply -f k8s/monitoring/prometheus-config.yaml
log_success "Prometheus config deployed"

log_info "Deploying Prometheus alert rules..."
kubectl apply -f k8s/monitoring/alert-rules.yaml
log_success "Alert rules deployed"

log_info "Deploying Prometheus..."
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml
log_success "Prometheus deployed"

log_info "Deploying Grafana configuration..."
kubectl apply -f k8s/monitoring/grafana-datasources.yml
kubectl apply -f k8s/monitoring/grafana-dashboard-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
log_success "Grafana config deployed"

log_info "Deploying Grafana..."
kubectl apply -f k8s/monitoring/grafana-deployment.yaml
log_success "Grafana deployed"

# Wait for monitoring pods
log_info "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -n monitoring --all --timeout=300s || {
  log_warning "Monitoring pods may still be starting"
}

# ============================================
# Step 8: Deploy ArgoCD
# ============================================
log_section "Step 8: Deploying ArgoCD"

log_info "Checking if ArgoCD is already installed..."
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
  log_success "ArgoCD already installed"
else
  log_info "Installing ArgoCD..."
  kubectl apply -f k8s/argocd/argocd-install-simple.yaml
  log_success "ArgoCD installed"
fi

log_info "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -n argocd --all --timeout=300s || {
  log_warning "ArgoCD pods may still be starting"
}

log_info "Configuring ArgoCD..."
kubectl apply -f k8s/argocd/argocd-configmap.yaml
kubectl apply -f k8s/argocd/argocd-certificate-issuer.yaml
log_success "ArgoCD configured"

log_info "Deploying ArgoCD application..."
kubectl apply -f k8s/argocd/payflow-application.yaml
log_success "ArgoCD application deployed"

# ============================================
# Step 9: Deploy Cloudflare Tunnel
# ============================================
log_section "Step 9: Deploying Cloudflare Tunnel"

log_info "Checking Cloudflare tunnel secret..."
if kubectl get secret cloudflare-tunnel-secret -n payflow &> /dev/null; then
  log_info "Deploying Cloudflare tunnel..."
  kubectl apply -f k8s/deployments/cloudflare-tunnel.yaml
  log_success "Cloudflare tunnel deployed"
else
  log_warning "Cloudflare tunnel secret not found. Skipping tunnel deployment."
  log_info "To deploy tunnel later:"
  log_info "  1. Create k8s/secrets/cloudflare-tunnel-secret.yaml"
  log_info "  2. Run: kubectl apply -f k8s/deployments/cloudflare-tunnel.yaml"
fi

# ============================================
# Step 10: Deploy Ingress
# ============================================
log_section "Step 10: Deploying Ingress"

log_info "Deploying ingress configurations..."
kubectl apply -f k8s/ingress/tls-ingress.yaml
kubectl apply -f k8s/ingress/monitoring-ingress.yaml
kubectl apply -f k8s/ingress/argocd-ingress.yaml
log_success "Ingress deployed"

# ============================================
# Step 11: Deploy Production Policies
# ============================================
log_section "Step 11: Deploying Production Policies"

log_info "Deploying policies..."
kubectl apply -f k8s/policies/pod-disruption-budgets.yaml
kubectl apply -f k8s/policies/resource-quotas.yaml
# Network policies disabled by default (can enable when needed)
# kubectl apply -f k8s/policies/network-policies.yaml
log_success "Policies deployed"

log_info "Deploying autoscaling..."
kubectl apply -f k8s/autoscaling/hpa-config.yaml
log_success "Autoscaling configured"

log_info "Deploying backups..."
kubectl apply -f k8s/backups/postgres-backup-cronjob.yaml
log_success "Backups configured"

log_info "Deploying security scanning..."
kubectl apply -f k8s/security/image-scanning-cronjob.yaml
log_success "Security scanning configured"

# ============================================
# Step 12: Get Service URLs
# ============================================
log_section "Step 12: Deployment Complete!"

log_info "Getting service URLs..."

# Get LoadBalancer IPs
API_IP=$(kubectl get svc api-gateway -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
PROMETHEUS_IP=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
log_success "🚀 PayFlow Deployment Complete!"
echo ""
echo "📊 Service Status:"
echo "  • Pods:"
kubectl get pods -n payflow --no-headers | wc -l | xargs echo "    - PayFlow services:"
kubectl get pods -n monitoring --no-headers | wc -l | xargs echo "    - Monitoring services:"
kubectl get pods -n argocd --no-headers | wc -l | xargs echo "    - ArgoCD services:"
echo ""
echo "🌐 Access URLs:"
echo "  • API Gateway: http://$API_IP (or http://api.payflow.local)"
echo "  • Frontend: http://payflow.local"
echo "  • Grafana: http://$GRAFANA_IP:3000 (or http://grafana.payflow.local)"
echo "  • Prometheus: http://$PROMETHEUS_IP:9090 (or http://prometheus.payflow.local)"
echo "  • ArgoCD: http://argocd.payflow.local"
echo ""
echo "☁️  Cloudflare (if configured):"
echo "  • Frontend: https://gameapp.games"
echo "  • API: https://app.gameapp.games"
echo "  • Grafana: https://grafana.gameapp.games"
echo "  • Prometheus: https://prometheus.gameapp.games"
echo "  • ArgoCD: https://argocd.gameapp.games"
echo ""
echo "📋 Next Steps:"
echo "  1. Add to /etc/hosts (if not already):"
echo "     $API_IP api.payflow.local www.payflow.local"
echo "     $GRAFANA_IP grafana.payflow.local prometheus.payflow.local"
echo "     $API_IP argocd.payflow.local"
echo ""
echo "  2. Check pod status:"
echo "     kubectl get pods -n payflow"
echo "     kubectl get pods -n monitoring"
echo "     kubectl get pods -n argocd"
echo ""
echo "  3. View logs:"
echo "     kubectl logs -n payflow deployment/api-gateway"
echo ""
echo "  4. Access Grafana:"
echo "     Username: admin"
echo "     Password: admin"
echo ""
echo "✨ Happy deploying!"

