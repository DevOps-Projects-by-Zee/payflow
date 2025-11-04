# Docker Compose Deployment Guide

## 🎯 **When to Use Docker Compose**

Docker Compose is perfect for:
- **Local development** and testing
- **Learning** how services interact
- **Quick prototyping** and demos
- **CI/CD pipelines** for testing
- **Single-machine deployments**

## 🚀 **Prerequisites**

- Docker Desktop or Colima
- Docker Compose v2+
- Git
- 4GB+ RAM available

## 📋 **Step-by-Step Manual Deployment**

### **Step 1: Environment Setup**

```bash
# Clone the repository
git clone <your-repo>
cd payflow

# Install Docker CLI (if using Colima)
brew install docker

# Start Colima (if using Colima instead of Docker Desktop)
colima start

# Switch to Colima context
docker context use colima

# Fix Docker credentials issue (if needed)
mkdir -p ~/.docker
echo '{"credsStore":""}' > ~/.docker/config.json
```

### **Step 2: Infrastructure Services**

```bash
# Start infrastructure services manually
docker-compose up -d postgres redis rabbitmq

# Verify infrastructure is healthy
docker-compose ps postgres redis rabbitmq

# Check logs if needed
docker-compose logs postgres
docker-compose logs redis  
docker-compose logs rabbitmq
```

### **Step 3: Database Migrations**

```bash
# Run database migrations manually
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V2__add_indexes.sql
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V3__add_2fa.sql

# Verify migrations
docker-compose exec postgres psql -U payflow -d payflow -c "\dt"
```

### **Step 4: Application Services**

```bash
# Start services manually (one by one to see any issues)
docker-compose up -d auth-service
docker-compose up -d wallet-service
docker-compose up -d transaction-service
docker-compose up -d notification-service
docker-compose up -d api-gateway
docker-compose up -d frontend

# Verify all services are healthy
docker-compose ps
```

### **Step 5: Monitoring Stack**

```bash
# Start monitoring services
docker-compose up -d prometheus grafana loki alertmanager promtail

# Verify monitoring stack
docker-compose ps | grep -E "(prometheus|grafana|loki|alertmanager)"

# Check Grafana is accessible
curl http://localhost:3006/api/health
```

## 🔍 **Verification Steps**

### **Service Health Checks**
```bash
# Check each service health
curl http://localhost:3000/health  # API Gateway
curl http://localhost:3001/health  # Wallet Service
curl http://localhost:3003/health  # Notification Service
curl http://localhost:3004/health  # Auth Service
curl http://localhost:3005/health  # Transaction Service
```

### **Application Access**
```bash
# Frontend Application
open http://localhost

# API Documentation
open http://localhost:3000/api-docs

# Monitoring Dashboard
open http://localhost:3006  # Grafana (admin/admin)
open http://localhost:9090  # Prometheus
open http://localhost:9093  # AlertManager
open http://localhost:15672 # RabbitMQ (payflow/payflow123)
```

### **Create Test User**
```bash
# Register a test user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'
```

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Port Conflicts**
```bash
# Check what's using ports
lsof -i :3000
lsof -i :3001

# Kill conflicting processes
kill -9 <PID>

# Or stop conflicting containers
docker stop $(docker ps -q --filter "publish=3000")
```

#### **Service Won't Start**
```bash
# Check service logs
docker-compose logs <service-name>

# Check service status
docker-compose ps <service-name>

# Restart specific service
docker-compose restart <service-name>
```

#### **Database Connection Issues**
```bash
# Check PostgreSQL status
docker-compose exec postgres psql -U payflow -d payflow -c "SELECT 1;"

# Check Redis status
docker-compose exec redis redis-cli ping

# Check RabbitMQ status
curl http://localhost:15672/api/overview
```

### **Health Check Issues**
```bash
# Check if health endpoints respond
curl http://localhost:3000/health

# Check Docker health status
docker-compose ps

# Check service logs for errors
docker-compose logs <service-name> | grep -i error
```

## 📊 **Monitoring**

### **View Metrics**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check service metrics
curl http://localhost:3000/metrics
curl http://localhost:3001/metrics

# Check Grafana dashboards
open http://localhost:3006
```

### **View Logs**
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f api-gateway
docker-compose logs -f auth-service
docker-compose logs -f wallet-service
```

## 🔄 **Maintenance**

### **Restart Services**
```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart <service-name>

# Restart with rebuild
docker-compose up -d --build <service-name>
```

### **Update Services**
```bash
# Pull latest images
docker-compose pull

# Rebuild and restart
docker-compose up -d --build
```

### **Clean Up**
```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: Deletes data)
docker-compose down -v

# Remove images
docker-compose down --rmi all

# Clean up Docker system
docker system prune -a
```

## 🚀 **Scripts Available (After Manual Understanding)**

Once you understand the manual process, you can use these scripts:

```bash
# Complete setup (after understanding manual steps)
./scripts/setup.sh

# Monitor system status
./scripts/monitor.sh

# Create test user
./scripts/create-user.sh

# Scale services
./scripts/scale-service.sh wallet-service 3

# Load testing
./scripts/load-test.sh

# Security scanning
./scripts/security-scan.sh

# Cleanup
./scripts/cleanup.sh
```

## 📚 **Next Steps**

After mastering Docker Compose deployment:

1. **k3d Local Kubernetes** - [k3d Deployment Guide](k3d-deployment.md)
2. **AWS Cloud Deployment** - [AWS Deployment Guide](aws-deployment.md)
3. **Azure Cloud Deployment** - [Azure Deployment Guide](azure-deployment.md)

## 🎯 **Learning Objectives**

By completing this guide, you'll understand:
- ✅ How microservices communicate
- ✅ Database migrations and setup
- ✅ Service health monitoring
- ✅ Container orchestration basics
- ✅ Troubleshooting techniques
- ✅ Production monitoring setup

**Remember: Manual deployment first, then automation!**