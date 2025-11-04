# MicroK8s Local Kubernetes Setup Guide

## 🎯 **Why MicroK8s?**

MicroK8s is perfect for learning Kubernetes locally because:
- ✅ **Production-like** - Real Kubernetes, not a simulator
- ✅ **Lightweight** - Runs on your Mac with minimal resources
- ✅ **Complete** - Includes all addons (DNS, Ingress, Storage, LoadBalancer)
- ✅ **Easy setup** - One command to enable addons
- ✅ **Same as production** - Works exactly like cloud Kubernetes

**Perfect for**: Learning Kubernetes without cloud costs, testing before cloud deployment, production-like local development.

---

## 🚀 **Prerequisites**

- macOS (we'll use Multipass for the VM)
- 8GB+ RAM available
- 20GB+ free disk space
- Basic terminal knowledge

---

## 📋 **Step-by-Step Setup**

### **Step 1: Install MicroK8s**

```bash
# Install Multipass (VM manager for MicroK8s on Mac)
brew install multipass

# Create MicroK8s VM (this takes 2-3 minutes)
multipass launch --name microk8s-vm --mem 4G --disk 20G --cpus 2

# Install MicroK8s inside the VM
multipass exec microk8s-vm -- sudo snap install microk8s --classic --channel=1.28/stable

# Add your user to microk8s group
multipass exec microk8s-vm -- sudo usermod -a -G microk8s ubuntu
multipass exec microk8s-vm -- sudo chown -R ubuntu ~/.kube

# Configure kubectl access from your Mac
multipass exec microk8s-vm -- microk8s config > ~/.kube/microk8s-config
export KUBECONFIG=~/.kube/microk8s-config

# Verify MicroK8s is running
multipass exec microk8s-vm -- microk8s status
```

**✅ Success**: You should see "microk8s is running"

---

### **Step 2: Enable Essential Addons**

```bash
# Enable DNS (required for service discovery)
multipass exec microk8s-vm -- microk8s enable dns

# Enable Ingress (for routing external traffic)
multipass exec microk8s-vm -- microk8s enable ingress

# Enable Storage (for PersistentVolumes)
multipass exec microk8s-vm -- microk8s enable storage

# Enable MetalLB (for LoadBalancer services - needed for local access)
multipass exec microk8s-vm -- microk8s enable metallb

# When prompted for IP range, use: 10.1.254.100-10.1.254.150
# (Check your VM IP first: multipass info microk8s-vm)

# Enable Registry (for pushing local Docker images)
multipass exec microk8s-vm -- microk8s enable registry

# Enable cert-manager (for TLS certificates)
multipass exec microk8s-vm -- microk8s enable cert-manager

# Verify all addons
multipass exec microk8s-vm -- microk8s status
```

**✅ Success**: All addons should show as "enabled"

---

### **Step 3: Build and Load Docker Images**

```bash
# Make sure Colima/Docker is running
colima status || colima start

# Set Docker context
docker context use colima

# Build all PayFlow images
cd /Users/mac/Documents/PayFlow

# Build images
docker build -t payflow/api-gateway:latest services/api-gateway
docker build -t payflow/auth-service:latest services/auth-service
docker build -t payflow/wallet-service:latest services/wallet-service
docker build -t payflow/transaction-service:latest services/transaction-service
docker build -t payflow/notification-service:latest services/notification-service
docker build -t payflow/frontend:latest services/frontend

# Load images into MicroK8s
docker save payflow/api-gateway:latest | multipass exec microk8s-vm -- docker load
docker save payflow/auth-service:latest | multipass exec microk8s-vm -- docker load
docker save payflow/wallet-service:latest | multipass exec microk8s-vm -- docker load
docker save payflow/transaction-service:latest | multipass exec microk8s-vm -- docker load
docker save payflow/notification-service:latest | multipass exec microk8s-vm -- docker load
docker save payflow/frontend:latest | multipass exec microk8s-vm -- docker load
```

**✅ Success**: Images loaded into MicroK8s registry

---

### **Step 4: Deploy PayFlow to MicroK8s**

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/microk8s-config

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy secrets
kubectl apply -f k8s/secrets/db-secrets.yaml

# Deploy configmaps
kubectl apply -f k8s/configmaps/app-config.yaml

# Deploy infrastructure (PostgreSQL, Redis, RabbitMQ)
kubectl apply -f k8s/statefulsets/postgres.yaml
kubectl apply -f k8s/deployments/redis.yaml
kubectl apply -f k8s/deployments/rabbitmq.yaml

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s

# Deploy application services
kubectl apply -f k8s/deployments/api-gateway.yaml
kubectl apply -f k8s/deployments/auth-service.yaml
kubectl apply -f k8s/deployments/wallet-service.yaml
kubectl apply -f k8s/deployments/transaction-service.yaml
kubectl apply -f k8s/deployments/notification-service.yaml
kubectl apply -f k8s/deployments/frontend.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -n payflow --all --timeout=300s

# Check status
kubectl get pods -n payflow
kubectl get svc -n payflow
```

**✅ Success**: All pods should be `Running`

---

### **Step 5: Deploy Monitoring Stack**

```bash
# Create monitoring namespace
kubectl apply -f k8s/monitoring-namespace.yaml

# Deploy Prometheus
kubectl apply -f k8s/monitoring/prometheus-config.yaml
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml

# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana-datasources.yml
kubectl apply -f k8s/monitoring/grafana-dashboard-config.yaml
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
kubectl apply -f k8s/monitoring/grafana-deployment.yaml

# Wait for monitoring pods
kubectl wait --for=condition=ready pod -n monitoring --all --timeout=300s

# Check monitoring services
kubectl get svc -n monitoring
```

**✅ Success**: Prometheus and Grafana pods running

---

### **Step 6: Configure Ingress and Access**

```bash
# Get LoadBalancer IP addresses
export API_IP=$(kubectl get svc api-gateway -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export GRAFANA_IP=$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Update /etc/hosts
echo "$API_IP api.payflow.local www.payflow.local" | sudo tee -a /etc/hosts
echo "$GRAFANA_IP grafana.payflow.local" | sudo tee -a /etc/hosts

# Deploy Ingress for HTTPS
kubectl apply -f k8s/ingress/tls-ingress.yaml
kubectl apply -f k8s/ingress/monitoring-ingress.yaml

# Wait for certificates to be issued
kubectl wait --for=condition=ready certificate -n payflow --all --timeout=300s
```

**✅ Success**: Access your services:
- Frontend: https://www.payflow.local
- API: https://api.payflow.local
- Grafana: https://grafana.payflow.local (admin/admin)

---

## 🔧 **Common Operations**

### **Check Pod Status**
```bash
kubectl get pods -n payflow
kubectl get pods -n monitoring
```

### **View Logs**
```bash
kubectl logs -n payflow deployment/api-gateway --tail=50
kubectl logs -n monitoring deployment/prometheus --tail=50
```

### **Restart a Service**
```bash
kubectl rollout restart deployment/api-gateway -n payflow
```

### **Scale a Service**
```bash
kubectl scale deployment/api-gateway --replicas=3 -n payflow
```

### **Access Pod Shell**
```bash
kubectl exec -it -n payflow deployment/api-gateway -- sh
```

---

## 🐛 **Troubleshooting**

### **Issue: Pods stuck in Pending**
```bash
# Check why pods can't start
kubectl describe pod <pod-name> -n payflow

# Common causes: Insufficient resources, missing secrets/configmaps
```

### **Issue: Services not accessible**
```bash
# Check if MetalLB assigned IPs
kubectl get svc -n payflow | grep LoadBalancer

# If <pending>, enable MetalLB:
multipass exec microk8s-vm -- microk8s enable metallb:10.1.254.100-10.1.254.150
```

### **Issue: Images not found**
```bash
# Rebuild and reload images
docker save payflow/api-gateway:latest | multipass exec microk8s-vm -- docker load

# Check image pull policy (should be "Never" for local)
kubectl get deployment api-gateway -n payflow -o yaml | grep imagePullPolicy
```

### **Issue: Certificate errors**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Restart cert-manager if needed
kubectl rollout restart deployment cert-manager -n cert-manager
```

---

## 📊 **What You've Learned**

By completing this MicroK8s setup, you've:
- ✅ Set up a production-like Kubernetes environment locally
- ✅ Deployed microservices with proper configuration
- ✅ Configured monitoring with Prometheus and Grafana
- ✅ Set up HTTPS with cert-manager
- ✅ Learned Kubernetes fundamentals (pods, services, deployments, ingress)

**Next Steps**: 
- Set up ArgoCD for GitOps automation → [argocd-setup.md](argocd-setup.md)
- Configure Cloudflare Tunnel for public access → See README
- Deploy to cloud (AWS/Azure) → [aws-deployment.md](aws-deployment.md)

---

## 🔗 **Related Documentation**

- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md) - Common issues and solutions
- [ArgoCD Setup](argocd-setup.md) - Next: GitOps automation
- [Docker Compose Setup](docker-compose-deployment.md) - Previous: Local development

