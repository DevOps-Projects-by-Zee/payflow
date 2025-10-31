#!/bin/bash
# ============================================
# scripts/setup.sh - Complete Setup Script
# ============================================
# #### This script sets up the entire PayFlow environment ####
# #### It checks prerequisites, creates directories, and prepares everything ####

set -e  # #### Exit immediately if any command fails ####

echo "🚀 PayFlow Production Setup"
echo "============================"
echo ""

# #### Color Definitions ####
# #### These variables define colors for terminal output ####
GREEN='\033[0;32m'  # #### Green color for success messages ####
YELLOW='\033[1;33m' # #### Yellow color for warnings ####
RED='\033[0;31m'   # #### Red color for errors ####
NC='\033[0m'       # #### No Color - reset to default ####

# #### Prerequisites Check ####
# #### Verify that all required tools are installed ####
echo "📋 Checking prerequisites..."

# #### Check if Docker is installed ####
command -v docker >/dev/null 2>&1 || { echo -e "${RED}❌ Docker is required but not installed.${NC}" >&2; exit 1; }
# #### Check if Docker Compose is installed ####
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}❌ Docker Compose is required but not installed.${NC}" >&2; exit 1; }
# #### Check if Node.js is installed ####
command -v node >/dev/null 2>&1 || { echo -e "${RED}❌ Node.js is required but not installed.${NC}" >&2; exit 1; }

echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo ""

# #### Directory Structure Creation ####
# #### Create all necessary directories for the project ####
echo "📁 Creating directory structure..."
mkdir -p services/{auth-service,api-gateway,wallet-service,transaction-service,notification-service,frontend}  # #### Service directories ####
mkdir -p k8s/{configmaps,secrets,deployments,services,statefulsets,ingress,monitoring}  # #### Kubernetes resources ####
mkdir -p migrations  # #### Database migration files ####
mkdir -p monitoring  # #### Monitoring configuration ####
mkdir -p logs        # #### Application logs ####
mkdir -p certs       # #### SSL certificates ####
echo -e "${GREEN}✅ Directory structure created${NC}"
echo ""

# #### Environment Configuration ####
# #### Set up environment variables ####
if [ ! -f .env ]; then  # #### Check if .env file exists ####
    echo "⚙️  Creating .env file..."
    cp .env.example .env  # #### Copy example to create .env ####
    echo -e "${YELLOW}⚠️  Please edit .env file with your configuration${NC}"
else
    echo -e "${GREEN}✅ .env file already exists${NC}"
fi
echo ""

# #### SSL Certificate Generation ####
# #### Generate self-signed certificates for HTTPS in development ####
if [ ! -f certs/server.key ]; then  # #### Check if certificates exist ####
    echo "🔐 Generating self-signed SSL certificates for development..."
    openssl req -x509 -newkey rsa:4096 -keyout certs/server.key -out certs/server.cert \
        -days 365 -nodes -subj "/CN=localhost"
    echo -e "${GREEN}✅ SSL certificates generated${NC}"
else
    echo -e "${GREEN}✅ SSL certificates already exist${NC}"
fi
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm run install:all
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Start infrastructure
echo "🐳 Starting infrastructure services..."
docker-compose up -d postgres redis rabbitmq
echo "⏳ Waiting for services to be ready (30 seconds)..."
sleep 30
echo -e "${GREEN}✅ Infrastructure services started${NC}"
echo ""

# Run database migrations
echo "🗄️  Running database migrations..."
for migration in migrations/*.sql; do
    if [ -f "$migration" ]; then
        echo "   Running $(basename $migration)..."
        docker-compose exec -T postgres psql -U payflow -d payflow -f /migrations/$(basename $migration)
    fi
done
echo -e "${GREEN}✅ Database migrations completed${NC}"
echo ""

# Start monitoring stack
echo "📊 Starting monitoring stack..."
docker-compose up -d prometheus grafana alertmanager loki promtail
echo -e "${GREEN}✅ Monitoring stack started${NC}"
echo ""

# Start application services
echo "🚀 Starting application services..."
docker-compose up -d auth-service wallet-service transaction-service notification-service api-gateway frontend
echo "⏳ Waiting for services to initialize (30 seconds)..."
sleep 30
echo -e "${GREEN}✅ Application services started${NC}"
echo ""

# Health check
echo "🏥 Running health checks..."
services=("api-gateway:3000" "auth-service:3004" "wallet-service:3001" "transaction-service:3002" "notification-service:3003")
all_healthy=true

for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if curl -f -s http://localhost:$port/health > /dev/null; then
        echo -e "   ${GREEN}✅ $name is healthy${NC}"
    else
        echo -e "   ${RED}❌ $name is not responding${NC}"
        all_healthy=false
    fi
done
echo ""

if [ "$all_healthy" = true ]; then
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
    echo ""
    echo "📍 Access Points:"
    echo "   Frontend:        http://localhost"
    echo "   API Gateway:     http://localhost:3000"
    echo "   API Docs:        http://localhost:3000/api-docs"
    echo "   Grafana:         http://localhost:3005 (admin/admin)"
    echo "   Prometheus:      http://localhost:9090"
    echo "   RabbitMQ:        http://localhost:15672 (payflow/payflow123)"
    echo ""
    echo "📚 Next Steps:"
    echo "   1. Edit .env file with your configurations"
    echo "   2. Create your first user: npm run create-user"
    echo "   3. View logs: docker-compose logs -f"
    echo "   4. Run tests: npm run test:all"
    echo ""
else
    echo -e "${RED}⚠️  Some services are not healthy. Check logs: docker-compose logs${NC}"
    exit 1
fi
