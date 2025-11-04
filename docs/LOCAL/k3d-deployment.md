# k3d Local Kubernetes Deployment Guide

## 🎯 **When to Use k3d**

k3d is perfect for:
- **Learning Kubernetes** locally
- **Testing Kubernetes manifests** before cloud deployment
- **Local development** with Kubernetes features
- **CI/CD testing** with real Kubernetes
- **Preparing for cloud deployment**

## 🚀 **Prerequisites**

- Docker Desktop or Colima
- kubectl CLI
- k3d CLI
- Git
- 6GB+ RAM available

## 📋 **Step-by-Step Manual Deployment**

### **Step 1: Install Prerequisites**

```bash
# Install kubectl
brew install kubectl

# Install k3d
brew install k3d

# Verify installations
kubectl version --client
k3d version
```

### **Step 2: Create k3d Cluster**

```bash
# Create k3d cluster with port mappings
k3d cluster create payflow \
  --port "80:80@loadbalancer" \
  --port "3000:3000@loadbalancer" \
  --port "3006:3006@loadbalancer" \
  --port "9090:9090@loadbalancer" \
  --port "9093:9093@loadbalancer" \
  --port "15672:15672@loadbalancer" \
  --agents 2

# Verify cluster is running
k3d cluster list
kubectl get nodes
```

### **Step 3: Create Namespace and ConfigMaps**

```bash
# Create namespace
kubectl create namespace payflow

# Create ConfigMaps
kubectl apply -f k8s/configmaps/ -n payflow

# Verify ConfigMaps
kubectl get configmaps -n payflow
```

### **Step 4: Create Secrets**

```bash
# Create secrets
kubectl apply -f k8s/secrets/ -n payflow

# Verify secrets
kubectl get secrets -n payflow
```

### **Step 5: Deploy Infrastructure Services**

```bash
# Deploy PostgreSQL
kubectl apply -f k8s/statefulsets/postgres-statefulset.yaml -n payflow

# Deploy Redis
kubectl apply -f k8s/statefulsets/redis-statefulset.yaml -n payflow

# Deploy RabbitMQ
kubectl apply -f k8s/statefulsets/rabbitmq-statefulset.yaml -n payflow

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n payflow --timeout=300s
```

### **Step 6: Run Database Migrations**

```bash
# Create migration job
kubectl apply -f k8s/jobs/migration-job.yaml -n payflow

# Wait for migration to complete
kubectl wait --for=condition=complete job/migration-job -n payflow --timeout=300s

# Check migration logs
kubectl logs job/migration-job -n payflow
```

### **Step 7: Deploy Application Services**

```bash
# Deploy services in order
kubectl apply -f k8s/deployments/auth-service-deployment.yaml -n payflow
kubectl apply -f k8s/deployments/wallet-service-deployment.yaml -n payflow
kubectl apply -f k8s/deployments/transaction-service-deployment.yaml -n payflow
kubectl apply -f k8s/deployments/notification-service-deployment.yaml -n payflow
kubectl apply -f k8s/deployments/api-gateway-deployment.yaml -n payflow
kubectl apply -f k8s/deployments/frontend-deployment.yaml -n payflow

# Wait for deployments to be ready
kubectl wait --for=condition=available deployment -l app=auth-service -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=wallet-service -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=transaction-service -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=notification-service -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=api-gateway -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=frontend -n payflow --timeout=300s
```

### **Step 8: Deploy Monitoring Stack**

```bash
# Deploy Prometheus
kubectl apply -f k8s/monitoring/prometheus-deployment.yaml -n payflow

# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana-deployment.yaml -n payflow

# Deploy AlertManager
kubectl apply -f k8s/monitoring/alertmanager-deployment.yaml -n payflow

# Deploy Loki
kubectl apply -f k8s/monitoring/loki-deployment.yaml -n payflow

# Wait for monitoring to be ready
kubectl wait --for=condition=available deployment -l app=prometheus -n payflow --timeout=300s
kubectl wait --for=condition=available deployment -l app=grafana -n payflow --timeout=300s
```

### **Step 9: Deploy Services and Ingress**

```bash
# Deploy all services
kubectl apply -f k8s/services/ -n payflow

# Deploy ingress
kubectl apply -f k8s/ingress/ingress.yaml -n payflow

# Verify services
kubectl get services -n payflow
kubectl get ingress -n payflow
```

## 🔍 **Verification Steps**

### **Check Pod Status**
```bash
# Check all pods
kubectl get pods -n payflow

# Check pod details
kubectl describe pod <pod-name> -n payflow

# Check pod logs
kubectl logs <pod-name> -n payflow
```

### **Check Service Health**
```bash
# Port forward to test services
kubectl port-forward svc/api-gateway 3000:3000 -n payflow &
kubectl port-forward svc/frontend 8080:80 -n payflow &

# Test health endpoints
curl http://localhost:3000/health
curl http://localhost:8080
```

### **Application Access**
```bash
# Access through ingress
curl http://localhost/api/health
curl http://localhost

# Access monitoring
curl http://localhost:3006  # Grafana
curl http://localhost:9090  # Prometheus
curl http://localhost:9093  # AlertManager
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Pod Not Starting**
```bash
# Check pod status
kubectl get pods -n payflow

# Check pod events
kubectl describe pod <pod-name> -n payflow

# Check pod logs
kubectl logs <pod-name> -n payflow

# Check resource usage
kubectl top pods -n payflow
```

#### **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints -n payflow

# Check service details
kubectl describe service <service-name> -n payflow

# Test service connectivity
kubectl exec -it <pod-name> -n payflow -- curl <service-name>:<port>/health
```

#### **Ingress Issues**
```bash
# Check ingress status
kubectl get ingress -n payflow

# Check ingress details
kubectl describe ingress payflow-ingress -n payflow

# Check ingress controller
kubectl get pods -n kube-system | grep traefik
```

#### **Database Connection Issues**
```bash
# Check PostgreSQL pod
kubectl get pods -l app=postgres -n payflow

# Check PostgreSQL logs
kubectl logs -l app=postgres -n payflow

# Test database connection
kubectl exec -it <postgres-pod> -n payflow -- psql -U payflow -d payflow -c "SELECT 1;"
```

### **Resource Issues**
```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n payflow

# Check resource requests/limits
kubectl describe pod <pod-name> -n payflow | grep -A 5 "Requests\|Limits"
```

## 📊 **Monitoring**

### **View Metrics**
```bash
# Port forward to Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n payflow &

# Access Prometheus
open http://localhost:9090

# Check targets
curl http://localhost:9090/api/v1/targets
```

### **View Logs**
```bash
# View logs for all pods
kubectl logs -l app=api-gateway -n payflow

# Follow logs
kubectl logs -f deployment/api-gateway -n payflow

# View logs from multiple pods
kubectl logs -l app=api-gateway -n payflow --tail=100
```

### **Grafana Dashboard**
```bash
# Port forward to Grafana
kubectl port-forward svc/grafana 3006:3000 -n payflow &

# Access Grafana
open http://localhost:3006
# Login: admin/admin
```

## 🔄 **Maintenance**

### **Scaling Services**
```bash
# Scale deployment
kubectl scale deployment api-gateway --replicas=3 -n payflow

# Check scaling
kubectl get pods -l app=api-gateway -n payflow
```

### **Updating Services**
```bash
# Update deployment
kubectl set image deployment/api-gateway api-gateway=payflow-api-gateway:latest -n payflow

# Check rollout status
kubectl rollout status deployment/api-gateway -n payflow

# Rollback if needed
kubectl rollout undo deployment/api-gateway -n payflow
```

### **Clean Up**
```bash
# Delete namespace (removes everything)
kubectl delete namespace payflow

# Delete k3d cluster
k3d cluster delete payflow

# Clean up Docker images
docker system prune -a
```

## 🚀 **Scripts Available (After Manual Understanding)**

Once you understand the manual process, you can use these scripts:

```bash
# Deploy to k3d (after understanding manual steps)
./scripts/deploy-k8s.sh

# Monitor Kubernetes resources
kubectl get all -n payflow

# Scale services
kubectl scale deployment api-gateway --replicas=3 -n payflow

# View logs
kubectl logs -f deployment/api-gateway -n payflow
```

## 📚 **Next Steps**

After mastering k3d deployment:

1. **AWS Cloud Deployment** - [AWS Deployment Guide](aws-deployment.md)
2. **Azure Cloud Deployment** - [Azure Deployment Guide](azure-deployment.md)
3. **Blue-Green Deployment** - [Deployment Strategies](DEPLOYMENT_STRATEGIES.md)

## 🎯 **Learning Objectives**

By completing this guide, you'll understand:
- ✅ Kubernetes concepts and resources
- ✅ Pod lifecycle and health checks
- ✅ Service discovery and networking
- ✅ ConfigMaps and Secrets management
- ✅ Ingress and load balancing
- ✅ Monitoring in Kubernetes
- ✅ Troubleshooting Kubernetes issues

**Remember: Manual deployment first, then automation!**