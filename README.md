# PayFlow - Production-Ready Fintech Platform

## 🎯 **Welcome to PayFlow!**

This is a **complete fintech microservices platform** designed for beginners to learn modern DevOps, microservices, and cloud deployment. No prior experience required!

### **What You'll Learn**
- 🏗️ **Microservices Architecture** - How to build scalable applications
- 🐳 **Docker & Containers** - Modern application packaging
- ☸️ **Kubernetes** - Container orchestration
- ☁️ **Cloud Deployment** - AWS and Azure
- 📊 **Monitoring & Observability** - Keeping systems healthy
- 🔒 **Security Best Practices** - Protecting financial data
- 🚀 **DevOps Automation** - Scripts and CI/CD

### **Time Commitment**
- **Total Time**: 4-6 weeks (2-3 hours per day)
- **Beginner Level**: 0-6 months experience
- **Prerequisites**: Basic computer skills, willingness to learn

## 🚀 **Quick Start - Let's Build PayFlow Together!**

### **🎯 Your Mission (Choose Your Adventure)**

**🎮 Option 1: "The Speed Runner" (30 minutes)**
```bash
# Just want to see it work? Let's go!
git clone <your-repo>
cd payflow
make start
open http://localhost
# 🎉 Done! You're now running a fintech platform!
```

**🎓 Option 2: "The Learner" (2 hours)**
```bash
# Want to understand what's happening? Perfect!
git clone <your-repo>
cd payflow

# Step 1: Explore the architecture
cat README.md  # Read the story above!

# Step 2: Start the services
make start

# Step 3: Watch the magic happen
docker-compose logs -f  # Watch all services start up

# Step 4: Test the application
open http://localhost
# Create account → Send money → Check monitoring dashboard
```

**🔬 Option 3: "The Explorer" (Half day)**
```bash
# Want to dive deep? Let's explore everything!

# 1. Start with the story
cat README.md

# 2. Understand the code
ls services/  # See all microservices
cat services/api-gateway/server.js  # Read the API Gateway code

# 3. Start the application
make start

# 4. Explore each service
curl http://localhost:3000/health  # API Gateway health
curl http://localhost:3001/health  # Wallet Service health
curl http://localhost:3004/health  # Auth Service health

# 5. Test the full flow
# Frontend: http://localhost
# API Docs: http://localhost:3000/api-docs  
# Monitoring: http://localhost:3006
```

### **🎪 Interactive Demo: "The Money Transfer Journey"**

**Step 1: Meet the User**
```bash
# Open the frontend
open http://localhost

# You'll see: "Welcome to PayFlow! Create your account"
# This is our React frontend talking to the API Gateway
```

**Step 2: The Authentication Drama**
```bash
# When you create an account, watch this happen:
docker-compose logs auth-service

# You'll see: "Creating new user with email..."
# The Auth Service is talking to PostgreSQL
```

**Step 3: The Money Transfer Adventure**
```bash
# When you send money, watch this sequence:
docker-compose logs wallet-service
docker-compose logs transaction-service  
docker-compose logs notification-service

# You'll see the entire microservices orchestra in action!
```

**Step 4: The Monitoring Show**
```bash
# Open Grafana to see the metrics
open http://localhost:3006
# Login: admin/admin

# You'll see real-time metrics of your money transfers!
```

### **🎯 Success Criteria**

**✅ You've mastered PayFlow when you can:**
- [ ] Explain what each microservice does
- [ ] Deploy the app using Docker Compose
- [ ] Deploy the app to Kubernetes (k3d)
- [ ] Deploy the app to the cloud (AWS/Azure)
- [ ] Monitor the app using Grafana
- [ ] Troubleshoot when something breaks
- [ ] Implement blue-green deployment

### **🏆 Achievement Unlocked!**

Once you complete PayFlow, you'll have:
- **Built a production-ready fintech platform**
- **Mastered microservices architecture**
- **Learned Kubernetes deployment**
- **Implemented monitoring and observability**
- **Practiced DevOps best practices**

**This is exactly what senior DevOps engineers do every day!** 🎉

## 📚 **Complete Learning Journey**

### **🎯 Week 1: Getting Started**

#### **Day 1-2: Understanding the Project**
**Goals:**
- Understand what PayFlow does
- Get the application running locally
- Explore the user interface

**Hands-On:**
```bash
# 1. Clone the repository
git clone <repository-url>
cd PayFlow

# 2. Start the application
make start

# 3. Open the application
open http://localhost

# 4. Create an account and send money
# Follow the prompts in the web interface
```

**Success Criteria:**
- [ ] Application is running
- [ ] You can create an account
- [ ] You can send money to another user
- [ ] You understand what PayFlow does

#### **Day 3-4: Understanding Docker**
**Goals:**
- Understand what Docker is
- Learn how containers work
- Explore the docker-compose.yml file

**Hands-On:**
```bash
# 1. Check running containers
docker ps

# 2. View container logs
docker-compose logs api-gateway

# 3. Stop and restart services
make stop
make start

# 4. Check service health
curl http://localhost:3000/health
```

#### **Day 5-7: Understanding the Code**
**Goals:**
- Read and understand the main service files
- Learn how authentication works
- Understand how money transfers work

**Hands-On:**
```bash
# 1. Read the API Gateway code
cat services/api-gateway/server.js

# 2. Test authentication
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Test wallet operations
curl -X GET http://localhost:3000/api/wallet/balance \
  -H "Authorization: Bearer YOUR_TOKEN"

# 4. View service logs
docker-compose logs -f
```

### **🎯 Week 2: Kubernetes & Local Deployment**

#### **Day 8-10: Understanding Kubernetes**
**Goals:**
- Understand what Kubernetes is
- Learn basic Kubernetes concepts
- Deploy PayFlow to local Kubernetes

**Hands-On:**
```bash
# 1. Install k3d (local Kubernetes)
brew install k3d

# 2. Create a Kubernetes cluster
k3d cluster create payflow-cluster --port "3000:3000@loadbalancer"

# 3. Deploy PayFlow to Kubernetes
./scripts/deploy-k8s.sh

# 4. Check deployments
kubectl get deployments -n payflow
kubectl get pods -n payflow
```

#### **Day 11-14: Monitoring & Observability**
**Goals:**
- Understand monitoring concepts
- Learn how to use Grafana
- Understand Prometheus metrics
- Learn how to troubleshoot issues

**Hands-On:**
```bash
# 1. Access Grafana dashboard
open http://localhost:3006
# Login: admin/admin

# 2. Access Prometheus
open http://localhost:9090

# 3. Generate some load
./scripts/load-test.sh

# 4. Check alerts
open http://localhost:9093
```

### **🎯 Week 3: Cloud Deployment**

#### **Day 15-17: AWS Deployment**
**Goals:**
- Understand cloud concepts
- Deploy PayFlow to AWS EKS
- Learn about AWS services

**Hands-On:**
```bash
# 1. Install AWS CLI
brew install awscli

# 2. Configure AWS credentials
aws configure

# 3. Create EKS cluster
eksctl create cluster --name payflow-cluster --region us-west-2

# 4. Deploy to AWS
./scripts/deploy-aws.sh
```

#### **Day 18-21: Azure Deployment**
**Goals:**
- Learn about Azure services
- Deploy PayFlow to Azure AKS
- Compare AWS and Azure

**Hands-On:**
```bash
# 1. Install Azure CLI
brew install azure-cli

# 2. Login to Azure
az login

# 3. Create AKS cluster
az aks create --resource-group payflow-rg --name payflow-cluster

# 4. Deploy to Azure
./scripts/deploy-azure.sh
```

### **🎯 Week 4: Production Operations**

#### **Day 22-24: Blue-Green Deployment**
**Goals:**
- Understand deployment strategies
- Learn blue-green deployment
- Practice zero-downtime deployments

**Hands-On:**
```bash
# 1. Understand current deployment
kubectl get deployments -n payflow

# 2. Practice blue-green deployment
./scripts/blue-green-deploy.sh

# 3. Monitor deployment
kubectl get pods -n payflow -w

# 4. Rollback if needed
kubectl rollout undo deployment/api-gateway -n payflow
```

#### **Day 25-28: Automation & Scripts**
**Goals:**
- Understand when to use scripts
- Learn about CI/CD
- Practice automation

**Hands-On:**
```bash
# 1. Run setup script
./scripts/setup.sh

# 2. Run monitoring script
./scripts/monitor.sh

# 3. Run load testing
./scripts/load-test.sh

# 4. Run security scanning
./scripts/security-scan.sh
```

## 📚 **Documentation - Deployment-Focused Learning Path**

### **🎯 Start Here**
- **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** - Your first steps with PayFlow

### **🚀 Deployment Guides (Manual First Approach)**

#### **Local Development & Learning**
- **[docs/docker-compose-deployment.md](docs/docker-compose-deployment.md)** - Docker Compose local deployment
- **[docs/k3d-deployment.md](docs/k3d-deployment.md)** - k3d local Kubernetes deployment

#### **Cloud Production Deployments**
- **[docs/aws-deployment.md](docs/aws-deployment.md)** - AWS EKS cloud deployment
- **[docs/azure-deployment.md](docs/azure-deployment.md)** - Azure AKS cloud deployment

### **🔧 Technical Reference**
- **[docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)** - How the code is organized
- **[docs/MONITORING_GUIDE.md](docs/MONITORING_GUIDE.md)** - Complete monitoring and troubleshooting guide
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[docs/OPERATIONS.md](docs/OPERATIONS.md)** - Production operations & blue-green deployment
- **[docs/SCRIPTS_GUIDE.md](docs/SCRIPTS_GUIDE.md)** - When and how to use scripts


## 🎯 **Deployment Strategy: Blue-Green Only**

PayFlow uses **Blue-Green deployment** for zero-downtime deployments:

```bash
# Deploy new version
make deploy SERVICE=api-gateway VERSION=v1.2.3

# Rollback if needed
make rollback SERVICE=api-gateway
```

## 🏗️ **The PayFlow Story: A Real Fintech Journey**

### **📖 Meet Sarah - Our Fintech Hero**

Imagine you're **Sarah**, a DevOps engineer at a growing fintech startup. Your company needs to build a money transfer app that can handle thousands of users safely and securely. This is exactly what PayFlow teaches you to build!

### **🎯 The Business Problem**

**Sarah's Challenge**: Build a production-ready fintech platform that can:
- Handle user registrations and authentication
- Process money transfers safely
- Scale to thousands of users
- Maintain 99.9% uptime
- Comply with financial regulations

### **🏗️ The Architecture Story**

```
👤 User Story: "I want to send money to my friend"

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🌐 Frontend   │    │  🚪 API Gateway │    │ 🔐 Auth Service │
│                 │    │                 │    │                 │
│ "Send $50 to    │───▶│ "Who are you?   │───▶│ "Let me check   │
│  John"          │    │  Let me route    │    │  your identity" │
│                 │    │  this request"   │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │ 💰 Wallet       │              │
         │              │    Service      │              │
         │              │                 │              │
         │              │ "Do you have    │              │
         │              │  enough money?" │              │
         │              └─────────────────┘              │
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │ 📊 Transaction  │              │
         │              │    Service      │              │
         │              │                 │              │
         │              │ "Processing     │              │
         │              │  transfer..."   │              │
         │              └─────────────────┘              │
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │ 📧 Notification │              │
         │              │    Service      │              │
         │              │                 │              │
         │              │ "Sending email  │              │
         │              │  confirmation"  │              │
         │              └─────────────────┘              │
         │                       │                       │
         │                       ▼                       │
         │              ┌─────────────────┐              │
         │              │ 🗄️ Databases    │              │
         │              │                 │              │
         │              │ PostgreSQL:     │              │
         │              │ - Users         │              │
         │              │ - Transactions  │              │
         │              │                 │              │
         │              │ Redis:          │              │
         │              │ - Sessions      │              │
         │              │ - Cache         │              │
         │              │                 │              │
         │              │ RabbitMQ:       │              │
         │              │ - Queues        │              │
         │              │ - Messages      │              │
         │              └─────────────────┘              │
```

### **🎭 The Microservices Drama**

**Act 1: The User Arrives**
- **Frontend**: "Welcome! Please log in or create an account"
- **API Gateway**: "I'll route your request to the right service"
- **Auth Service**: "Let me verify who you are"

**Act 2: The Money Transfer**
- **Wallet Service**: "Do you have enough money? Let me check your balance"
- **Transaction Service**: "I'll process this transfer safely"
- **Notification Service**: "I'll send confirmation emails"

**Act 3: The Happy Ending**
- **User**: "Money sent successfully! ✅"
- **System**: "Transaction recorded, emails sent, everyone happy!"

### **🔧 Why This Architecture?**

**Sarah's Reasoning**:
- **Microservices**: Each service has one job (Single Responsibility Principle)
- **API Gateway**: One entry point for security and routing
- **Databases**: PostgreSQL for data, Redis for speed, RabbitMQ for reliability
- **Monitoring**: We need to know if anything breaks!

### **📊 The Technology Stack Story**

| Service | Technology | Why Sarah Chose It |
|---------|------------|-------------------|
| **Frontend** | React + Tailwind | "Users need a beautiful, responsive interface" |
| **API Gateway** | Node.js + Express | "Fast, reliable, great ecosystem" |
| **Auth Service** | JWT + bcrypt | "Secure authentication without complexity" |
| **Wallet Service** | PostgreSQL | "ACID transactions for money - non-negotiable!" |
| **Transaction Service** | RabbitMQ | "Reliable message processing for financial data" |
| **Notification Service** | Nodemailer | "Users need confirmation emails" |
| **Monitoring** | Prometheus + Grafana | "We need to see what's happening!" |

### **🎯 The Learning Journey**

**Week 1**: "Let me understand what PayFlow does"
**Week 2**: "Let me see how Docker containers work"
**Week 3**: "Let me deploy this to Kubernetes"
**Week 4**: "Let me make this production-ready!"

### **🚀 The Production Reality**

**Sarah's Production Checklist**:
- ✅ **Security**: HTTPS, rate limiting, input validation
- ✅ **Monitoring**: Metrics, logs, alerts
- ✅ **Scalability**: Multiple replicas, load balancing
- ✅ **Reliability**: Health checks, circuit breakers
- ✅ **Compliance**: Audit logs, data encryption

## 🎓 **Career Progression - Manual First Approach**

- **Beginner**: Manual deployments (Docker Compose → k3d → Blue-Green)
- **Intermediate**: Scripted deployments (AWS EKS → Cloudflare → CI/CD)  
- **Advanced**: ArgoCD GitOps (Manual ArgoCD → Automated GitOps)

## 🎮 **Make PayFlow Fun: Interactive Learning**

### **🎯 Gamification Ideas**

**🏆 Achievement System**:
- 🥉 **Bronze**: "First Docker Container" - Successfully run PayFlow locally
- 🥈 **Silver**: "Kubernetes Master" - Deploy to k3d successfully  
- 🥇 **Gold**: "Cloud Deployer" - Deploy to AWS/Azure
- 💎 **Platinum**: "Production Hero" - Complete blue-green deployment

**🎲 Challenge Mode**:
```bash
# Challenge 1: "The Great Migration"
# Move from Docker Compose to Kubernetes without breaking anything!

# Challenge 2: "The Load Test"
# Handle 1000 concurrent users - can your system survive?

# Challenge 3: "The Security Audit" 
# Find and fix 5 security vulnerabilities

# Challenge 4: "The Disaster Recovery"
# Simulate a database failure and recover gracefully
```

### **🎭 Role-Playing Scenarios**

**👨‍💼 Scenario 1: "The Startup CTO"**
- You're the CTO of a fintech startup
- Your app needs to handle 10,000 users
- Budget is tight, but security is critical
- **Your Mission**: Deploy PayFlow to production on a budget

**👩‍💻 Scenario 2: "The DevOps Consultant"**
- A client's payment system is down
- They need zero-downtime deployment
- **Your Mission**: Implement blue-green deployment

**🔒 Scenario 3: "The Security Auditor"**
- A bank wants to audit your fintech platform
- They need proof of security measures
- **Your Mission**: Implement comprehensive monitoring and security

### **🎪 Interactive Demos**

**🎬 Live Demo Scripts**:
```bash
# Demo 1: "The Money Transfer Journey"
# Show exactly what happens when a user sends money

# Demo 2: "The Scaling Story" 
# Start with 1 user, scale to 1000 users

# Demo 3: "The Failure Recovery"
# Break something, then fix it live

# Demo 4: "The Security Showdown"
# Try to hack the system, then show defenses
```

### **🎨 Visual Learning**

**📊 Architecture Diagrams**:
- Interactive service diagrams
- Real-time data flow visualization
- Performance metrics dashboard
- Error tracking and debugging

**🎥 Video Tutorials**:
- "5-minute PayFlow overview"
- "Docker Compose explained"
- "Kubernetes deployment walkthrough"
- "Monitoring and troubleshooting"

### **🎯 Beginner-Friendly Features**

**🚀 Quick Wins**:
- One-click local setup
- Pre-configured test data
- Built-in user accounts
- Sample transactions

**📚 Learning Aids**:
- Inline code explanations
- "Why this matters" sections
- Common mistakes and fixes
- Real-world examples

**🎮 Interactive Elements**:
- Terminal commands with explanations
- Clickable architecture diagrams
- Progress tracking
- Achievement badges

## 🚀 **What You'll Learn**

- ✅ Microservices architecture
- ✅ Kubernetes deployment
- ✅ Blue-Green deployments
- ✅ Monitoring and observability
- ✅ Production operations
- ✅ GitOps with ArgoCD

---


### **📖 Additional Resources**
- **[API Documentation](http://localhost:3000/api-docs)** - Interactive API documentation
- **[Monitoring Dashboard](http://localhost:3006)** - Grafana dashboards
- **[Prometheus Metrics](http://localhost:9090)** - Metrics and alerts

### **🤖 Scripts (Use After Manual Understanding)**

**⚠️ Important**: Scripts are provided for convenience **AFTER** you understand the manual deployment process. Always complete manual deployments first to learn what's happening under the hood.

#### **Available Scripts**
- `./scripts/setup.sh` - Complete Docker Compose setup
- `./scripts/deploy-k8s.sh` - Deploy to k3d Kubernetes
- `./scripts/deploy-aws.sh` - Deploy to AWS EKS
- `./scripts/deploy-azure.sh` - Deploy to Azure AKS
- `./scripts/monitor.sh` - System monitoring dashboard
- `./scripts/create-user.sh` - Create test users
- `./scripts/scale-service.sh` - Scale services
- `./scripts/load-test.sh` - Load testing
- `./scripts/security-scan.sh` - Security scanning
- `./scripts/cleanup.sh` - Clean up resources

#### **When to Use Scripts**
- ✅ **After** completing manual deployments
- ✅ **After** understanding each step
- ✅ **For** repetitive tasks
- ✅ **For** CI/CD automation
- ❌ **Not** for learning (use manual steps first)

---

## Quick Start (Docker Compose)

1. **Clone repository**
   ```bash
   git clone https://github.com/your-org/payflow.git
   cd payflow
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your secrets
   ```

3. **Start all services**
   ```bash
   docker-compose up -d
   ```

4. **Run database migrations**
   ```bash
   docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql
   ```

5. **Access services**
   - Frontend: http://localhost
   - API Gateway: http://localhost:3000
   - API Documentation: http://localhost:3000/api-docs
   - Grafana: http://localhost:3006 (admin/admin)
   - RabbitMQ Management: http://localhost:15672 (payflow/payflow123)
   - Prometheus: http://localhost:9090

6. **Create first user**
   ```bash
   curl -X POST http://localhost:3000/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{
       "email": "user@example.com",
       "password": "SecurePass123!",
       "name": "John Doe"
     }'
   ```

### Kubernetes Deployment

1. **Prerequisites**
   - Kubernetes cluster (EKS, GKE, AKS, or local)
   - kubectl configured
   - Helm 3.x installed

2. **Install cert-manager (for TLS)**
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
   ```

3. **Deploy application**
   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/configmaps/
   kubectl apply -f k8s/secrets/
   kubectl apply -f k8s/statefulsets/
   kubectl apply -f k8s/deployments/
   kubectl apply -f k8s/services/
   kubectl apply -f k8s/ingress/
   ```

4. **Deploy monitoring**
   ```bash
   kubectl apply -f k8s/monitoring/
   ```

5. **Verify deployment**
   ```bash
   kubectl get pods -n payflow
   kubectl get svc -n payflow
   ```

### Development Workflow

1. **Run tests**
   ```bash
   npm test
   npm run test:integration
   npm run test:smoke
   ```

2. **Run linting**
   ```bash
   npm run lint
   npm run lint:fix
   ```

3. **Build Docker images**
   ```bash
   docker-compose build
   ```

4. **View logs**
   ```bash
   docker-compose logs -f [service-name]
   kubectl logs -f deployment/[service-name] -n payflow
   ```

### Monitoring & Observability

1. **View metrics**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3006

2. **Check service health**
   ```bash
   curl http://localhost:3000/api/metrics
   ```

3. **View logs**
   - Loki/Grafana: http://localhost:3005

4. **Alerts**
   - AlertManager: http://localhost:9093

### Security Checklist

- [ ] Change default passwords in .env
- [ ] Configure HTTPS/TLS certificates
- [ ] Set up proper CORS origins
- [ ] Enable 2FA for admin accounts
- [ ] Configure firewall rules
- [ ] Set up secret rotation
- [ ] Enable audit logging
- [ ] Configure rate limiting
- [ ] Set up DDoS protection
- [ ] Regular security scans

### Production Checklist

- [ ] All services passing health checks
- [ ] Monitoring dashboards configured
- [ ] Alerts configured and tested
- [ ] Backup strategy implemented
- [ ] Disaster recovery plan documented
- [ ] Load testing completed
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Team trained on operations
- [ ] Runbooks created

### Troubleshooting

**Service won't start**
```bash
docker-compose logs [service-name]
kubectl logs deployment/[service-name] -n payflow
```

**Database connection issues**
```bash
docker-compose exec postgres psql -U payflow -d payflow
```

**RabbitMQ queue backup**
```bash
curl -u payflow:payflow123 http://localhost:15672/api/queues
```

### Support

- Documentation: https://docs.payflow.com
- Issues: https://github.com/your-org/payflow/issues
- Slack: https://payflow.slack.com

---

## Installation & Setup Instructions

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd payflow
   ```

2. **Install all dependencies**
   ```bash
   npm run install:all
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configurations
   ```

4. **Start infrastructure with Docker Compose**
   ```bash
   docker-compose up -d postgres redis rabbitmq
   ```

5. **Run database migrations**
   ```bash
   docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql
   docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V2__add_indexes.sql
   docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V3__add_2fa.sql
   ```

6. **Start all services**
   ```bash
   # Option 1: Using Docker Compose (recommended)
   docker-compose up -d

   # Option 2: Run services individually for development
   npm run dev:auth       # Terminal 1
   npm run dev:gateway    # Terminal 2
   npm run dev:wallet     # Terminal 3
   npm run dev:transaction # Terminal 4
   npm run dev:notification # Terminal 5
   npm run dev:frontend   # Terminal 6
   ```

7. **Access the application**
   - Frontend: http://localhost
   - API Gateway: http://localhost:3000
   - API Docs: http://localhost:3000/api-docs
   - Grafana: http://localhost:3006
   - RabbitMQ: http://localhost:15672
   - Prometheus: http://localhost:9090

8. **Create your first user**
   ```bash
   curl -X POST http://localhost:3000/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{
       "email": "user@example.com",
       "password": "SecurePass123!",
       "name": "John Doe"
     }'
   ```

### Running Tests

```bash
# Run all tests
npm run test:all

# Run tests for specific service
cd services/auth-service && npm test
cd services/api-gateway && npm test
cd services/wallet-service && npm test
cd services/transaction-service && npm test
cd services/notification-service && npm test
```

### Linting

```bash
# Lint all services
npm run lint:all

# Fix linting issues
cd services/auth-service && npm run lint:fix
```

### Docker Commands

```bash
# Build all images
npm run docker:build

# Start all services
npm run docker:up

# Stop all services
npm run docker:down

# View logs
npm run docker:logs

# View specific service logs
docker-compose logs -f api-gateway
```

### Kubernetes Deployment

```bash
# Deploy to Kubernetes
npm run k8s:deploy

# Check status
npm run k8s:status

# Delete deployment
npm run k8s:delete
```

### Monitoring

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3005 (login: admin/admin)
- **AlertManager**: http://localhost:9093

### Troubleshooting

**Services won't start:**
```bash
docker-compose down
docker-compose up -d
docker-compose logs -f
```

**Database connection issues:**
```bash
docker-compose exec postgres psql -U payflow -d payflow
```

**Reset everything:**
```bash
docker-compose down -v
docker-compose up -d
```

---

## Database Migrations

PayFlow uses Flyway for database schema management with versioned migrations:

### Migration Files
- `migrations/V1__initial_schema.sql` - Initial database schema
- `migrations/V2__add_indexes.sql` - Performance indexes
- `migrations/V3__add_2fa.sql` - Two-factor authentication support

### Running Migrations
```bash
# Local development
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql

# Production (with Flyway)
flyway -configFiles=flyway.conf migrate
```

## CI/CD Pipeline

### GitHub Actions Workflow
The project includes a comprehensive CI/CD pipeline with:

**Test Stage:**
- Unit tests with Jest
- Integration tests with Supertest
- Security scanning with Trivy
- Code coverage reporting
- Linting with ESLint

**Build Stage:**
- Multi-service Docker image building
- Container registry publishing
- Image caching for faster builds

**Deploy Stages:**
- Staging deployment on `develop` branch
- Production deployment on `main` branch
- Blue-green deployment strategy
- Slack notifications

### Pipeline Features
- **Multi-service builds** with matrix strategy
- **Security scanning** with vulnerability detection
- **Automated testing** with database services
- **Blue-green deployments** for zero-downtime
- **Environment-specific configurations**
- **Rollback capabilities**

## Testing Framework

### Test Structure
```
services/
├── test/
│   ├── unit/           # Unit tests
│   ├── integration/    # Integration tests
│   └── smoke/          # Smoke tests
├── jest.config.js      # Jest configuration
└── package.json        # Test dependencies
```

### Test Commands
```bash
npm test                # Run all tests with coverage
npm run test:unit       # Unit tests only
npm run test:integration # Integration tests
npm run test:smoke      # Smoke tests
npm run test:watch      # Watch mode
```

### Test Coverage
- **80% minimum coverage** requirement
- **Branch coverage** tracking
- **Function coverage** monitoring
- **Statement coverage** validation

## Architecture Overview

```
┌─────────────┐    ┌─────────────┐
│   Frontend  │    │   Ingress   │
│  (React)    │    │             │
└──────┬──────┘    └──────┬──────┘
       │                  │
       └──────────────────┼──────────────────┐
                          │                  │
                    ┌─────▼──────────┐       │
                    │   API Gateway  │       │
                    │   (Node.js)    │       │
                    └────┬────┬───┬───┘       │
                         │    │   │   │       │
                         ▼    ▼   ▼   ▼       │
                   ┌────────┐ ┌──────────┐ ┌────────────┐ ┌─────────┐
                   │ Wallet │ │Transaction│ │Notification│ │   Auth  │
                   │Service │ │  Service  │ │  Service   │ │ Service │
                   └───┬────┘ └────┬─────┘ └─────┬──────┘ └────┬────┘
                       │           │              │              │
                       ▼           ▼              ▼              ▼
                   ┌────────┐ ┌─────────┐   ┌─────────┐   ┌─────────┐
                   │Postgres│ │RabbitMQ │   │  Redis  │   │  Redis  │
                   │   DB   │ │ Queue   │   │  Cache  │   │Blacklist│
                   └────────┘ └─────────┘   └─────────┘   └─────────┘
```

---

## 1. Frontend Service (React)

A modern, responsive React application with Tailwind CSS providing a beautiful user interface for the PayFlow platform.

### Features:
- **Modern UI/UX**: Clean, professional design with Tailwind CSS
- **Real-time Updates**: Live transaction status and notifications
- **Responsive Design**: Mobile-first approach with responsive layouts
- **JWT Authentication**: Secure token-based authentication
- **Transaction Management**: Send money, view history, and monitor status
- **System Monitoring**: Real-time microservices health monitoring
- **Error Handling**: Comprehensive error handling and user feedback

### Technology Stack:
- **React 18**: Modern React with hooks and functional components
- **Tailwind CSS**: Utility-first CSS framework
- **Lucide React**: Beautiful, customizable icons
- **Fetch API**: Modern HTTP client for API communication
- **Local Storage**: Client-side token and user data persistence

### Key Components:
- **Login/Register**: Secure authentication with form validation
- **Dashboard**: Balance overview, transaction metrics, and notifications
- **Send Money**: Transaction creation with recipient selection
- **Activity**: Transaction history with real-time status updates
- **Monitoring**: Microservices health and system architecture overview

### API Integration:
- **RESTful API**: Full integration with PayFlow microservices
- **Real-time Updates**: Polling for live transaction status
- **Error Handling**: Graceful error handling with user feedback
- **Token Management**: Automatic token refresh and logout

---

## 2. API Gateway Service

The API Gateway serves as the single entry point for all client requests. It handles routing, rate limiting, and provides a unified API interface.

### Features:
- **Authentication**: JWT-based authentication middleware
- **Authorization**: Role-based access control (RBAC)
- **Rate Limiting**: Different limits for different endpoints
- **Security**: Helmet.js for security headers
- **Logging**: Morgan for request logging
- **Health Monitoring**: Aggregated health checks from all services
- **Input Validation**: Express-validator for request validation
- **API Documentation**: Swagger/OpenAPI documentation
- **HTTPS Support**: TLS/SSL configuration for production

### API Documentation:
- **Swagger UI**: Interactive API documentation at `/api-docs`
- **OpenAPI Spec**: Machine-readable API specification at `/api-docs.json`
- **Authentication**: JWT Bearer token authentication
- **Request/Response Examples**: Complete examples for all endpoints
- **Error Codes**: Detailed error response documentation

### Endpoints:
- `GET /health` - Gateway health check
- `GET /api-docs` - Interactive API documentation
- `GET /api-docs.json` - OpenAPI specification
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Token refresh
- `POST /api/auth/logout` - User logout
- `GET /api/auth/me` - Get user profile
- `GET /api/wallets` - Get user wallets
- `POST /api/wallets` - Create wallet
- `POST /api/transactions` - Create transaction
- `GET /api/transactions` - Get transactions
- `GET /api/notifications/:userId` - Get notifications
- `GET /api/admin/metrics` - Admin metrics (admin only)
- `GET /api/metrics` - Public metrics

---

## 3. Auth Service

The Auth Service handles user authentication, authorization, and session management with comprehensive security features.

### Features:
- **JWT Authentication**: Access and refresh token management
- **Password Security**: bcrypt hashing with salt rounds
- **Account Lockout**: Protection against brute force attacks
- **Token Blacklisting**: Redis-based token revocation
- **Audit Logging**: Complete audit trail of user actions
- **Session Management**: Secure session handling
- **Input Validation**: Comprehensive request validation
- **Rate Limiting**: Protection against abuse

### Database Schema:
```sql
-- Users table
CREATE TABLE users (
  id VARCHAR(50) PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  role VARCHAR(20) DEFAULT 'user',
  is_active BOOLEAN DEFAULT true,
  email_verified BOOLEAN DEFAULT false,
  two_factor_enabled BOOLEAN DEFAULT false,
  two_factor_secret VARCHAR(255),
  failed_login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP,
  last_login_ip VARCHAR(45)
);

-- Refresh tokens table
CREATE TABLE refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(50) REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(500) UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  ip_address VARCHAR(45),
  user_agent TEXT
);

-- Audit logs table
CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(50),
  action VARCHAR(100) NOT NULL,
  resource VARCHAR(100),
  ip_address VARCHAR(45),
  user_agent TEXT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Endpoints:
- `GET /health` - Service health check
- `POST /auth/register` - Register new user
- `POST /auth/login` - User login
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Logout and revoke tokens
- `POST /auth/verify` - Verify token (internal)
- `GET /auth/me` - Get current user profile
- `POST /auth/change-password` - Change password

---

## 4. Wallet Service

Manages user wallets and balances with PostgreSQL persistence and Redis caching.

### Features:
- **ACID Transactions**: Database-level locking for balance updates
- **Redis Caching**: 30-60 second cache for wallet data
- **Demo Data**: Pre-populated with sample users
- **Health Checks**: Database and Redis connectivity monitoring

### Database Schema:
```sql
CREATE TABLE wallets (
  user_id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
  currency VARCHAR(3) DEFAULT 'USD',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Endpoints:
- `GET /health` - Service health check
- `GET /wallets` - List all wallets (cached)
- `GET /wallets/:userId` - Get wallet by user ID (cached)
- `POST /wallets/transfer` - Internal transfer endpoint

---

## 5. Transaction Service

Handles transaction processing with asynchronous queue-based architecture using RabbitMQ.

### Features:
- **Async Processing**: RabbitMQ message queues for scalability
- **Transaction States**: PENDING → PROCESSING → COMPLETED/FAILED
- **Error Handling**: 10% random failure simulation for demo
- **Notifications**: Automatic notification generation
- **Metrics**: Transaction status tracking
- **Auto-Reversal**: Automatic timeout handling for stuck transactions (after 1 minute)

### Database Schema:
```sql
CREATE TABLE transactions (
  id VARCHAR(50) PRIMARY KEY,
  from_user_id VARCHAR(50) NOT NULL,
  to_user_id VARCHAR(50) NOT NULL,
  amount DECIMAL(15,2) NOT NULL,
  status VARCHAR(20) NOT NULL,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  processing_started_at TIMESTAMP,
  completed_at TIMESTAMP
);
```

### Endpoints:
- `GET /health` - Service health check
- `POST /transactions` - Create new transaction
- `GET /transactions` - List transactions with filters
- `GET /transactions/:txnId` - Get specific transaction
- `GET /metrics` - Transaction metrics

### Auto-Reversal System:
PayFlow implements a **CronJob-based auto-reversal system** that automatically reverses stuck pending transactions after 1 minute, mimicking real banking behavior.

**How it works:**
- Runs every minute via Kubernetes CronJob
- Finds pending transactions older than 1 minute
- Updates them to FAILED status with error message
- Releases held funds back to user balance
- Prevents "insufficient funds" errors from stuck transactions

**Configuration:**
- Located in `k8s/jobs/transaction-timeout.yaml`
- Uses PostgreSQL environment variables for secure access
- No secrets exposed in configuration files

---

## 6. Notification Service

Processes notifications asynchronously and stores them in PostgreSQL.

### Features:
- **Queue Processing**: RabbitMQ consumer for notifications
- **Persistent Storage**: PostgreSQL for notification history
- **Read Status**: Mark notifications as read
- **User Filtering**: Get notifications by user ID

### Database Schema:
```sql
CREATE TABLE notifications (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  type VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  transaction_id VARCHAR(50),
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Endpoints:
- `GET /health` - Service health check
- `GET /notifications/:userId` - Get user notifications
- `PUT /notifications/:id/read` - Mark notification as read

---

## 7. Infrastructure Components

### PostgreSQL (StatefulSet)
- **Persistent Storage**: 10Gi volume claim
- **ACID Compliance**: Full transaction support
- **Health Checks**: Readiness and liveness probes

### Redis (Deployment)
- **Caching Layer**: Fast data retrieval
- **Session Storage**: User session management
- **Health Monitoring**: Ping-based health checks

### RabbitMQ (Deployment)
- **Message Queues**: Reliable message delivery
- **Management UI**: Web interface on port 15672
- **Durability**: Persistent queues and messages

---

## Quick Start

### Local Development (Docker Compose)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Test API Gateway
curl http://localhost:3000/health

# Register a new user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123","name":"Test User"}'

# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123"}'

# Get wallets (requires authentication)
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  http://localhost:3000/api/wallets

# Send money (requires authentication)
curl -X POST http://localhost:3000/api/transactions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{"fromUserId":"user-001","toUserId":"user-002","amount":100}'

# Check transaction status
curl http://localhost:3000/api/transactions

# Get notifications (requires authentication)
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  http://localhost:3000/api/notifications/user-001

# Check Prometheus metrics
curl http://localhost:3002/metrics

# Check DLQ status
curl http://localhost:3002/admin/dlq

# Create idempotent transaction
curl -X POST http://localhost:3000/api/transactions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Idempotency-Key: unique-key-123" \
  -d '{"fromUserId":"user-001","toUserId":"user-002","amount":100}'

# Stop all services
docker-compose down
```

### Kubernetes Deployment

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Apply configs and secrets
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/secrets/

# Deploy databases
kubectl apply -f k8s/statefulsets/

# Deploy services
kubectl apply -f k8s/deployments/

# Check status
kubectl get pods -n payflow

# Get API Gateway URL
kubectl get svc api-gateway -n payflow

# View logs
kubectl logs -f deployment/transaction-service -n payflow
```

### Build and Push Images

```bash
# Build images
cd services/api-gateway && docker build -t payflow/api-gateway:latest .
cd ../wallet-service && docker build -t payflow/wallet-service:latest .
cd ../transaction-service && docker build -t payflow/transaction-service:latest .
cd ../notification-service && docker build -t payflow/notification-service:latest .

# Push to registry (replace with your registry)
docker tag payflow/api-gateway:latest your-registry/payflow/api-gateway:latest
docker push your-registry/payflow/api-gateway:latest
# Repeat for other services
```

---

## Production Features

✅ **Real PostgreSQL database** with ACID transactions
✅ **Redis caching** for wallet data
✅ **RabbitMQ message queue** for async processing
✅ **JWT Authentication** with access and refresh tokens
✅ **Password Security** with bcrypt hashing
✅ **Account Lockout** protection against brute force
✅ **Token Blacklisting** for secure logout
✅ **Audit Logging** for compliance and security
✅ **Role-Based Access Control** (RBAC)
✅ **Input Validation** with express-validator
✅ **Rate Limiting** with different limits per endpoint
✅ **Structured Logging** with Winston and correlation IDs
✅ **Prometheus Metrics** for comprehensive monitoring
✅ **Distributed Tracing** with correlation IDs
✅ **Circuit Breakers** for service resilience
✅ **Retry Mechanisms** with exponential backoff
✅ **Idempotency** for safe retries
✅ **Dead Letter Queues** for failed message handling
✅ **Database Query Monitoring** with timing metrics
✅ **Queue Depth Monitoring** for RabbitMQ
✅ **Health Checks** with detailed status reporting
✅ **Horizontal Pod Autoscaling** based on CPU
✅ **StatefulSets** for databases
✅ **Resource limits** and requests
✅ **Service discovery** via Kubernetes DNS
✅ **ConfigMaps** and Secrets
✅ **Transaction atomicity** with database locks
✅ **Event-driven notifications**
✅ **Security headers** with Helmet.js
✅ **Request logging** with Morgan
✅ **Graceful error handling**
✅ **Database indexing** for performance
✅ **Connection pooling** for PostgreSQL
✅ **Cache invalidation** strategies
✅ **API Documentation** with Swagger/OpenAPI
✅ **HTTPS/TLS Support** for production security
✅ **Email Notifications** with HTML templates
✅ **SMS Notifications** via Twilio integration
✅ **Security Alerts** and automated notifications
✅ **Welcome Emails** for user onboarding
✅ **Password Reset** via secure email links

## New Features

### API Documentation
- **Swagger UI**: Interactive API documentation at `/api-docs`
- **OpenAPI Specification**: Machine-readable API spec at `/api-docs.json`
- **Authentication Examples**: JWT Bearer token usage
- **Request/Response Schemas**: Complete data models
- **Error Documentation**: Detailed error codes and messages

### HTTPS/TLS Security
- **Production TLS**: Let's Encrypt certificate management
- **Self-signed Certificates**: Development HTTPS support
- **Certificate Management**: Automated certificate renewal
- **Security Headers**: Enhanced security configuration
- **Mutual TLS**: Optional client certificate authentication

### Email Notification System
- **SMTP Integration**: Support for Gmail, SendGrid, AWS SES
- **HTML Templates**: Rich, responsive email designs
- **Transaction Alerts**: Real-time payment notifications
- **Welcome Emails**: User onboarding sequences
- **Security Alerts**: Suspicious activity notifications
- **Password Reset**: Secure password recovery

### SMS Notification System
- **Twilio Integration**: Reliable SMS delivery
- **Transaction Alerts**: Real-time SMS notifications
- **2FA Support**: Two-factor authentication codes
- **Security Alerts**: Critical security notifications
- **International Support**: Global SMS delivery

## Monitoring and Observability

### Structured Logging
- **Winston Logger**: JSON-formatted logs with timestamps
- **Correlation IDs**: Track requests across services
- **Log Levels**: Configurable logging levels (error, warn, info, debug)
- **Service Context**: Automatic service identification in logs
- **Error Stack Traces**: Full stack traces for debugging

### Prometheus Metrics
- **HTTP Request Metrics**: Duration, count, status codes
- **Transaction Metrics**: Processing time, success/failure rates
- **Database Metrics**: Query duration and error rates
- **Queue Metrics**: Message depth and processing rates
- **System Metrics**: CPU, memory, and connection counts
- **Custom Business Metrics**: Transaction types, user activity

### Distributed Tracing
- **Correlation IDs**: Unique identifiers for request tracking
- **Cross-Service Tracing**: Follow requests through microservices
- **Performance Monitoring**: Identify bottlenecks and slow operations
- **Error Propagation**: Track errors across service boundaries

### Circuit Breakers
- **Service Protection**: Prevent cascade failures
- **Automatic Recovery**: Self-healing when services recover
- **Fallback Mechanisms**: Graceful degradation
- **Monitoring**: Circuit state changes and failure rates

### Retry Mechanisms
- **Exponential Backoff**: Intelligent retry timing
- **Transient Error Detection**: Smart retry decisions
- **Maximum Retry Limits**: Prevent infinite loops
- **Retry Metrics**: Track retry attempts and success rates

### Idempotency
- **Safe Retries**: Prevent duplicate operations
- **Redis-Based Caching**: Fast idempotency checks
- **Request Deduplication**: Handle duplicate requests gracefully
- **Cache TTL**: Automatic cleanup of old idempotency keys

### Dead Letter Queues
- **Failed Message Handling**: Capture messages that can't be processed
- **Retry Logic**: Automatic retry with backoff
- **Manual Recovery**: Admin endpoints for DLQ management
- **Monitoring**: Track DLQ depth and retry attempts

### Health Checks
- All services expose `/health` endpoints
- Database connectivity monitoring
- Redis ping checks
- RabbitMQ connection status
- Queue depth monitoring
- Detailed service status reporting

### Metrics Endpoints
- Transaction status counts
- Service health aggregation
- Resource utilization tracking
- Custom business metrics
- Prometheus-compatible metrics format

## Security Considerations

- **JWT Authentication**: Secure token-based authentication
- **Password Security**: bcrypt hashing with salt rounds
- **Account Lockout**: Protection against brute force attacks
- **Token Blacklisting**: Redis-based token revocation
- **Rate Limiting**: Prevents API abuse
- **Security Headers**: Helmet.js protection
- **Input Validation**: Comprehensive request validation
- **Database Credentials**: Kubernetes secrets
- **Network Policies**: Service-to-service communication
- **SQL Injection Prevention**: Parameterized queries
- **Audit Logging**: Complete audit trail for compliance
- **CORS Configuration**: Controlled cross-origin requests
- **Payload Size Limits**: Protection against large payload attacks

## Resilience Patterns

### Circuit Breaker Pattern
- **Automatic Failure Detection**: Monitors service health
- **Fast Failure**: Prevents cascade failures
- **Recovery Testing**: Periodic health checks
- **Fallback Responses**: Graceful degradation

### Retry Pattern
- **Exponential Backoff**: Increasing delays between retries
- **Jitter**: Randomization to prevent thundering herd
- **Transient Error Detection**: Smart retry decisions
- **Circuit Breaker Integration**: Respects circuit states

### Idempotency Pattern
- **Request Deduplication**: Prevent duplicate operations
- **Safe Retries**: Handle network failures gracefully
- **Cache-Based**: Fast idempotency checks
- **TTL Management**: Automatic cleanup

### Dead Letter Queue Pattern
- **Failed Message Capture**: Store unprocessable messages
- **Retry Logic**: Automatic retry with backoff
- **Manual Recovery**: Admin intervention capabilities
- **Monitoring**: Track DLQ metrics

### Bulkhead Pattern
- **Resource Isolation**: Separate connection pools
- **Failure Containment**: Prevent resource exhaustion
- **Independent Scaling**: Scale components separately

## Scaling Strategies

- **Horizontal Pod Autoscaling**: CPU-based scaling
- **Database Connection Pooling**: Efficient connection management
- **Redis Caching**: Reduces database load
- **Message Queues**: Decouples processing
- **Stateless Services**: Easy horizontal scaling

This architecture demonstrates real-world fintech microservices patterns with production-ready features for handling financial transactions at scale.