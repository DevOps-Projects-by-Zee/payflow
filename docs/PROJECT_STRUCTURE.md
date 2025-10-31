# Project Structure

## 📁 **PayFlow Project Structure**

```
payflow/
├── 📁 services/                          # Microservices
│   ├── 📁 api-gateway/                   # API Gateway Service
│   ├── 📁 auth-service/                  # Authentication Service
│   ├── 📁 wallet-service/                # Wallet Management Service
│   ├── 📁 transaction-service/           # Transaction Processing Service
│   ├── 📁 notification-service/          # Notification Service
│   ├── 📁 frontend/                      # React Frontend
│   └── 📁 shared/                        # Shared utilities
│
├── 📁 k8s/                              # Kubernetes manifests
│   ├── 📁 deployments/                  # Service deployments
│   ├── 📁 configmaps/                   # Configuration maps
│   ├── 📁 secrets/                      # Secret definitions
│   ├── 📁 services/                     # Service definitions
│   ├── 📁 ingress/                      # Ingress configurations
│   └── 📁 monitoring/                   # Monitoring stack
│
├── 📁 scripts/                          # Operational scripts
│   ├── 📄 setup.sh                      # Complete setup script
│   ├── 📄 deploy-k8s.sh                 # Kubernetes deployment
│   ├── 📄 monitor.sh                    # Monitoring script
│   └── 📄 cleanup.sh                    # Cleanup script
│
├── 📁 docs/                             # Documentation
│   ├── 📄 GETTING_STARTED.md            # Your first steps
│   ├── 📄 docker-compose-deployment.md  # Docker Compose guide
│   ├── 📄 k3d-deployment.md             # k3d Kubernetes guide
│   ├── 📄 aws-deployment.md             # AWS deployment guide
│   ├── 📄 azure-deployment.md           # Azure deployment guide
│   ├── 📄 TROUBLESHOOTING.md            # Troubleshooting guide
│   ├── 📄 SCRIPTS_GUIDE.md              # Scripts usage guide
│   ├── 📄 OPERATIONS.md                 # Production operations
│   └── 📄 PROJECT_STRUCTURE.md          # This file
│
├── 📁 monitoring/                       # Monitoring configuration
│   ├── 📄 prometheus.yml                # Prometheus config
│   ├── 📄 alerts.yml                    # Alert rules
│   └── 📁 grafana-dashboards/           # Grafana dashboards
│
├── 📁 migrations/                       # Database migrations
│   ├── 📄 V1__initial_schema.sql        # Initial schema
│   ├── 📄 V2__add_indexes.sql           # Database indexes
│   └── 📄 V3__add_2fa.sql               # Two-factor auth
│
├── 📄 docker-compose.yml                # Docker Compose configuration
├── 📄 Makefile                          # Build automation
├── 📄 README.md                         # Project overview
└── 📄 .env.example                      # Environment variables template
```

## 🎯 **Key Directories**

### **services/**
Contains all microservices:
- **api-gateway**: Routes requests, handles authentication
- **auth-service**: User authentication and authorization
- **wallet-service**: Wallet management and balance tracking
- **transaction-service**: Transaction processing and validation
- **notification-service**: Email/SMS notifications
- **frontend**: React web application
- **shared**: Common utilities and libraries

### **k8s/**
Kubernetes deployment manifests:
- **deployments**: Service deployment configurations
- **configmaps**: Configuration data
- **secrets**: Sensitive data (passwords, keys)
- **services**: Service networking
- **ingress**: External access configuration
- **monitoring**: Prometheus, Grafana, AlertManager

### **scripts/**
Operational automation scripts:
- **setup.sh**: Complete environment setup
- **deploy-k8s.sh**: Kubernetes deployment
- **monitor.sh**: System monitoring
- **cleanup.sh**: Resource cleanup

### **docs/**
Comprehensive documentation:
- **GETTING_STARTED.md**: Entry point for new users
- **docker-compose-deployment.md**: Local development
- **k3d-deployment.md**: Local Kubernetes
- **aws-deployment.md**: AWS cloud deployment
- **azure-deployment.md**: Azure cloud deployment
- **TROUBLESHOOTING.md**: Common issues and solutions
- **SCRIPTS_GUIDE.md**: When and how to use scripts
- **OPERATIONS.md**: Production operations

## 🚀 **Getting Started**

1. **Start Here**: Read `docs/GETTING_STARTED.md`
2. **Local Development**: Follow `docs/docker-compose-deployment.md`
3. **Kubernetes Learning**: Use `docs/k3d-deployment.md`
4. **Cloud Deployment**: Choose `docs/aws-deployment.md` or `docs/azure-deployment.md`
5. **Production**: Follow `docs/OPERATIONS.md`

## 🔧 **Development Workflow**

### **Local Development**
```bash
# Start with Docker Compose
docker-compose up -d

# Access application
open http://localhost
```

### **Kubernetes Testing**
```bash
# Deploy to k3d
./scripts/deploy-k8s.sh

# Access application
kubectl port-forward svc/frontend 8080:80 -n payflow
```

### **Cloud Deployment**
```bash
# Deploy to AWS
./scripts/deploy-aws.sh

# Deploy to Azure
./scripts/deploy-azure.sh
```

## 📊 **Monitoring**

- **Grafana**: http://localhost:3006 (admin/admin)
- **Prometheus**: http://localhost:9090
- **AlertManager**: http://localhost:9093

## 🛠️ **Troubleshooting**

- **Common Issues**: See `docs/TROUBLESHOOTING.md`
- **Service Logs**: `docker-compose logs <service>`
- **Kubernetes Logs**: `kubectl logs <pod> -n payflow`
- **Health Checks**: `curl http://localhost:3000/health`