# AWS Cloud Deployment Guide

## 🎯 **When to Use AWS EKS**

AWS EKS is perfect for:
- **Production deployments** with high availability
- **Auto-scaling** based on demand
- **Enterprise security** requirements
- **Global distribution** across regions
- **Cost optimization** with spot instances
- **Integration** with AWS services (RDS, ElastiCache, SQS)

## 🚀 **Prerequisites**

- AWS CLI configured with appropriate permissions
- kubectl installed
- eksctl installed
- Docker images pushed to ECR
- AWS account with EKS permissions
- 8GB+ RAM available locally

## 📋 **Step-by-Step Manual Deployment**

### **Step 1: Install AWS Tools**

```bash
# Install AWS CLI
brew install awscli

# Install eksctl
brew install eksctl

# Install kubectl
brew install kubectl

# Verify installations
aws --version
eksctl version
kubectl version --client
```

### **Step 2: Configure AWS CLI**

```bash
# Configure AWS CLI
aws configure

# Enter your credentials:
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-west-2
# Default output format: json

# Test configuration
aws sts get-caller-identity
```

### **Step 3: Create EKS Cluster Manually**

```bash
# Create EKS cluster with specific configuration
eksctl create cluster \
  --name payflow-cluster \
  --region us-west-2 \
  --nodegroup-name payflow-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --managed \
  --ssh-access \
  --ssh-public-key ~/.ssh/id_rsa.pub \
  --with-oidc \
  --managed

# Wait for cluster creation (10-15 minutes)
# Verify cluster is ready
kubectl get nodes
```

### **Step 4: Configure kubectl**

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name payflow-cluster

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### **Step 5: Create Namespace and ConfigMaps**

```bash
# Create namespace
kubectl create namespace payflow

# Create ConfigMaps
kubectl apply -f k8s/configmaps/ -n payflow

# Verify ConfigMaps
kubectl get configmaps -n payflow
```

### **Step 6: Create Secrets**

```bash
# Create secrets
kubectl apply -f k8s/secrets/ -n payflow

# Verify secrets
kubectl get secrets -n payflow
```

### **Step 7: Deploy Infrastructure Services**

```bash
# Deploy PostgreSQL (using AWS RDS is recommended for production)
kubectl apply -f k8s/statefulsets/postgres-statefulset.yaml -n payflow

# Deploy Redis (using AWS ElastiCache is recommended for production)
kubectl apply -f k8s/statefulsets/redis-statefulset.yaml -n payflow

# Deploy RabbitMQ (using AWS SQS is recommended for production)
kubectl apply -f k8s/statefulsets/rabbitmq-statefulset.yaml -n payflow

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n payflow --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n payflow --timeout=300s
```

### **Step 8: Run Database Migrations**

```bash
# Create migration job
kubectl apply -f k8s/jobs/migration-job.yaml -n payflow

# Wait for migration to complete
kubectl wait --for=condition=complete job/migration-job -n payflow --timeout=300s

# Check migration logs
kubectl logs job/migration-job -n payflow
```

### **Step 9: Deploy Application Services**

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

### **Step 10: Deploy Monitoring Stack**

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

### **Step 11: Deploy Services and Ingress**

```bash
# Deploy all services
kubectl apply -f k8s/services/ -n payflow

# Deploy ingress with AWS Load Balancer
kubectl apply -f k8s/ingress/aws-ingress.yaml -n payflow

# Verify services
kubectl get services -n payflow
kubectl get ingress -n payflow
```

### **Step 12: Configure AWS Load Balancer**

```bash
# Wait for Load Balancer to be provisioned
kubectl wait --for=condition=ready ingress payflow-ingress -n payflow --timeout=300s

# Get Load Balancer URL
kubectl get ingress payflow-ingress -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Note: It may take 5-10 minutes for the Load Balancer to be ready
```

### **3. Create ECR Repositories**
```bash
# Create ECR repositories for each service
aws ecr create-repository --repository-name payflow/auth-service
aws ecr create-repository --repository-name payflow/wallet-service
aws ecr create-repository --repository-name payflow/transaction-service
aws ecr create-repository --repository-name payflow/notification-service
aws ecr create-repository --repository-name payflow/api-gateway
aws ecr create-repository --repository-name payflow/frontend
```

### **4. Build and Push Images**
```bash
# Get ECR login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build and push images
docker build -t payflow/auth-service ./services/auth-service
docker tag payflow/auth-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/payflow/auth-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/payflow/auth-service:latest

# Repeat for all services...
```

### **5. Deploy Infrastructure**
```bash
# Deploy RDS PostgreSQL
aws rds create-db-instance \
  --db-instance-identifier payflow-postgres \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username payflow \
  --master-user-password payflow123 \
  --allocated-storage 20

# Deploy ElastiCache Redis
aws elasticache create-cache-cluster \
  --cache-cluster-id payflow-redis \
  --cache-node-type cache.t3.micro \
  --engine redis \
  --num-cache-nodes 1

# Deploy Amazon MQ (RabbitMQ)
aws mq create-broker \
  --broker-name payflow-rabbitmq \
  --broker-instance-type mq.t3.micro \
  --engine-type RABBITMQ \
  --engine-version 3.8.11 \
  --host-instance-type mq.t3.micro \
  --deployment-mode SINGLE_INSTANCE
```

### **6. Deploy Application**
```bash
# Create namespace
kubectl create namespace payflow

# Deploy application services
kubectl apply -f k8s/aws/

# Wait for deployment
kubectl wait --for=condition=ready pod -l app=auth-service --timeout=300s
```

### **7. Configure Load Balancer**
```bash
# Deploy AWS Load Balancer Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/v2_4_4_full.yaml

# Create ingress
kubectl apply -f k8s/aws/ingress.yaml
```

---

## 🌐 **Access Your Application**

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | https://payflow.yourdomain.com | 💳 PayFlow Web App |
| **API Gateway** | https://api.payflow.yourdomain.com | 🔌 API Endpoint |
| **API Docs** | https://api.payflow.yourdomain.com/api-docs | 📚 Swagger Documentation |
| **Grafana** | https://monitor.payflow.yourdomain.com | 📊 Monitoring Dashboard |

---

## 🔧 **Using Scripts**

### **When to Use Scripts vs Manual Commands**

**Use Scripts When:**
- ✅ You understand AWS services
- ✅ You want to automate cloud deployment
- ✅ You're comfortable with AWS CLI

**Use Manual Commands When:**
- ✅ Learning AWS services
- ✅ Debugging cloud issues
- ✅ Understanding AWS architecture

### **Available Scripts**

```bash
# Deploy to AWS
./scripts/deploy-aws.sh

# Scale EKS nodes
eksctl scale nodegroup --cluster=payflow-cluster --name=payflow-nodes --nodes=5

# Monitor AWS resources
./scripts/monitor-aws.sh
```

---

## 🎯 **Testing Your Deployment**

### **1. Check EKS Cluster**
```bash
# Check cluster status
eksctl get cluster

# Check node groups
eksctl get nodegroup --cluster=payflow-cluster

# Check pods
kubectl get pods -n payflow
```

### **2. Test Application**
```bash
# Get load balancer URL
kubectl get ingress payflow-ingress

# Test application
curl https://payflow.yourdomain.com/health
```

### **3. Check AWS Resources**
```bash
# Check RDS instance
aws rds describe-db-instances --db-instance-identifier payflow-postgres

# Check ElastiCache
aws elasticache describe-cache-clusters --cache-cluster-id payflow-redis

# Check EKS cluster
aws eks describe-cluster --name payflow-cluster
```

---

## 🛠️ **Common Operations**

### **Scaling EKS Cluster**
```bash
# Scale node group
eksctl scale nodegroup --cluster=payflow-cluster --name=payflow-nodes --nodes=5

# Auto-scaling
kubectl apply -f k8s/aws/hpa.yaml
```

### **Rolling Updates**
```bash
# Update deployment
kubectl set image deployment/auth-service auth-service=<account-id>.dkr.ecr.us-west-2.amazonaws.com/payflow/auth-service:v2

# Check rollout
kubectl rollout status deployment/auth-service
```

### **Backup and Restore**
```bash
# Backup RDS
aws rds create-db-snapshot --db-instance-identifier payflow-postgres --db-snapshot-identifier payflow-backup-$(date +%Y%m%d)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot --db-instance-identifier payflow-postgres-restored --db-snapshot-identifier payflow-backup-20231201
```

---

## 🚨 **Troubleshooting**

### **EKS Cluster Issues**
```bash
# Check cluster status
aws eks describe-cluster --name payflow-cluster

# Check node group
eksctl get nodegroup --cluster=payflow-cluster

# Check cluster logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/payflow-cluster
```

### **Pod Issues**
```bash
# Check pod events
kubectl describe pod <pod-name> -n payflow

# Check pod logs
kubectl logs <pod-name> -n payflow

# Check resource usage
kubectl top pods -n payflow
```

### **Database Connection Issues**
```bash
# Check RDS endpoint
aws rds describe-db-instances --db-instance-identifier payflow-postgres --query 'DBInstances[0].Endpoint.Address'

# Test database connectivity
kubectl run db-test --image=postgres:15 --rm -it -- psql -h <rds-endpoint> -U payflow -d payflow
```

### **Load Balancer Issues**
```bash
# Check load balancer
kubectl get ingress -n payflow

# Check AWS Load Balancer
aws elbv2 describe-load-balancers --names payflow-lb
```

---

## 💰 **Cost Optimization**

### **Right-Sizing Resources**
```bash
# Use smaller instance types for development
eksctl create nodegroup --cluster=payflow-cluster --name=dev-nodes --node-type t3.small --nodes=1

# Use spot instances for non-critical workloads
eksctl create nodegroup --cluster=payflow-cluster --name=spot-nodes --node-type t3.medium --nodes=2 --spot
```

### **Auto-Scaling**
```bash
# Configure cluster autoscaler
kubectl apply -f k8s/aws/cluster-autoscaler.yaml

# Configure HPA
kubectl apply -f k8s/aws/hpa.yaml
```

---

## 🔒 **Security Best Practices**

### **IAM Roles**
```bash
# Create service account with IAM role
eksctl create iamserviceaccount \
  --cluster=payflow-cluster \
  --namespace=payflow \
  --name=payflow-sa \
  --role-name=PayFlowServiceRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

### **Network Security**
```bash
# Create security groups
aws ec2 create-security-group --group-name payflow-sg --description "PayFlow Security Group"

# Configure network policies
kubectl apply -f k8s/aws/network-policies.yaml
```

---

## 🧹 **Cleanup**

### **Delete Application**
```bash
# Delete Kubernetes resources
kubectl delete namespace payflow

# Delete ECR repositories
aws ecr delete-repository --repository-name payflow/auth-service --force
```

### **Delete Infrastructure**
```bash
# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier payflow-postgres --skip-final-snapshot

# Delete ElastiCache
aws elasticache delete-cache-cluster --cache-cluster-id payflow-redis

# Delete EKS cluster
eksctl delete cluster --name payflow-cluster
```

---

## 📚 **Next Steps**

After mastering AWS deployment:

1. **Azure Production** - [Azure Deployment Guide](docs/azure-deployment.md)
2. **Blue-Green Deployment** - [Blue-Green Guide](docs/blue-green-deployment.md)
3. **CI/CD Pipeline** - [CI/CD Guide](docs/cicd-guide.md)

---

## 🎓 **What You've Learned**

- ✅ AWS EKS managed Kubernetes
- ✅ ECR container registry
- ✅ RDS managed databases
- ✅ ElastiCache managed Redis
- ✅ AWS Load Balancer Controller
- ✅ Cloud security and IAM
- ✅ Cost optimization strategies

**Congratulations!** You've successfully deployed PayFlow on AWS! 🎉
