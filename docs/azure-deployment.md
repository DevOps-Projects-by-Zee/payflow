# Azure Cloud Deployment Guide

## 🎯 **When to Use Azure AKS**

Azure AKS is perfect for:
- **Microsoft ecosystem** integration
- **Enterprise security** with Azure AD
- **Hybrid cloud** scenarios
- **Cost optimization** with Azure Spot VMs
- **Global distribution** across Azure regions
- **Integration** with Azure services (Azure Database, Redis Cache, Service Bus)

## 🚀 **Prerequisites**

- Azure CLI configured with appropriate permissions
- kubectl installed
- Docker images pushed to Azure Container Registry
- Azure account with AKS permissions
- 8GB+ RAM available locally

## 📋 **Step-by-Step Manual Deployment**

### **Step 1: Install Azure Tools**

```bash
# Install Azure CLI
brew install azure-cli

# Install kubectl
brew install kubectl

# Verify installations
az --version
kubectl version --client
```

### **Step 2: Configure Azure CLI**

```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account list --output table
az account set --subscription "Your Subscription Name"

# Test configuration
az account show
```

### **Step 3: Create Resource Group**

```bash
# Create resource group
az group create \
  --name payflow-rg \
  --location eastus

# Verify resource group
az group show --name payflow-rg
```

### **Step 4: Create AKS Cluster Manually**

```bash
# Create AKS cluster with specific configuration
az aks create \
  --resource-group payflow-rg \
  --name payflow-cluster \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-addons monitoring \
  --enable-managed-identity \
  --generate-ssh-keys \
  --location eastus

# Wait for cluster creation (10-15 minutes)
# Verify cluster is ready
az aks get-credentials --resource-group payflow-rg --name payflow-cluster
kubectl get nodes
```

### **Step 5: Configure kubectl**

```bash
# Get AKS credentials
az aks get-credentials --resource-group payflow-rg --name payflow-cluster

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### **Step 6: Create Namespace and ConfigMaps**

```bash
# Create namespace
kubectl create namespace payflow

# Create ConfigMaps
kubectl apply -f k8s/configmaps/ -n payflow

# Verify ConfigMaps
kubectl get configmaps -n payflow
```

### **Step 7: Create Secrets**

```bash
# Create secrets
kubectl apply -f k8s/secrets/ -n payflow

# Verify secrets
kubectl get secrets -n payflow
```

### **Step 8: Deploy Infrastructure Services**

```bash
# Deploy PostgreSQL (using Azure Database for PostgreSQL is recommended for production)
kubectl apply -f k8s/statefulsets/postgres-statefulset.yaml -n payflow

# Deploy Redis (using Azure Cache for Redis is recommended for production)
kubectl apply -f k8s/statefulsets/redis-statefulset.yaml -n payflow

# Deploy RabbitMQ (using Azure Service Bus is recommended for production)
kubectl apply -f k8s/statefulsets/rabbitmq-statefulset.yaml -n payflow

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n payflow --timeout=300s
```

### **Step 9: Run Database Migrations**

```bash
# Create migration job
kubectl apply -f k8s/jobs/migration-job.yaml -n payflow

# Wait for migration to complete
kubectl wait --for=condition=complete job/migration-job -n payflow --timeout=300s

# Check migration logs
kubectl logs job/migration-job -n payflow
```

### **Step 10: Deploy Application Services**

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

### **Step 11: Deploy Monitoring Stack**

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

### **Step 12: Deploy Services and Ingress**

```bash
# Deploy all services
kubectl apply -f k8s/services/ -n payflow

# Deploy ingress with Azure Application Gateway
kubectl apply -f k8s/ingress/azure-ingress.yaml -n payflow

# Verify services
kubectl get services -n payflow
kubectl get ingress -n payflow
```

### **Step 13: Configure Azure Load Balancer**

```bash
# Wait for Load Balancer to be provisioned
kubectl wait --for=condition=ready ingress payflow-ingress -n payflow --timeout=300s

# Get Load Balancer IP
kubectl get ingress payflow-ingress -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Note: It may take 5-10 minutes for the Load Balancer to be ready
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
# Get Load Balancer IP
LB_IP=$(kubectl get ingress payflow-ingress -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access through Load Balancer
curl http://$LB_IP/api/health
curl http://$LB_IP
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **AKS Cluster Creation Failed**
```bash
# Check resource group
az group show --name payflow-rg

# Check AKS cluster status
az aks show --resource-group payflow-rg --name payflow-cluster

# Check node pool status
az aks nodepool list --resource-group payflow-rg --cluster-name payflow-cluster
```

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

#### **Load Balancer Issues**
```bash
# Check ingress status
kubectl get ingress -n payflow

# Check ingress details
kubectl describe ingress payflow-ingress -n payflow

# Check Azure Load Balancer
az network lb list --resource-group MC_payflow-rg_payflow-cluster_eastus
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

# Delete AKS cluster
az aks delete --resource-group payflow-rg --name payflow-cluster

# Delete resource group
az group delete --name payflow-rg --yes --no-wait
```

## 🚀 **Scripts Available (After Manual Understanding)**

Once you understand the manual process, you can use these scripts:

```bash
# Deploy to Azure (after understanding manual steps)
./scripts/deploy-azure.sh

# Monitor Azure resources
az aks show --resource-group payflow-rg --name payflow-cluster

# Scale AKS cluster
az aks scale --resource-group payflow-rg --name payflow-cluster --node-count 5
```

## 📚 **Next Steps**

After mastering Azure deployment:

1. **Blue-Green Deployment** - [Deployment Strategies](DEPLOYMENT_STRATEGIES.md)
2. **Production Optimization** - [Operations Guide](OPERATIONS.md)
3. **CI/CD Pipeline** - [GitHub Actions Guide](CI_CD.md)

## 🎯 **Learning Objectives**

By completing this guide, you'll understand:
- ✅ Azure AKS cluster management
- ✅ Azure Load Balancer configuration
- ✅ Azure Container Registry integration
- ✅ Azure monitoring and logging
- ✅ Azure security and networking
- ✅ Troubleshooting Azure issues
- ✅ Cost optimization strategies

**Remember: Manual deployment first, then automation!**
