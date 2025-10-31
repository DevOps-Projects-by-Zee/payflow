# #### PayFlow Makefile ####
# #### This file provides simple commands for common PayFlow operations ####
# #### Use 'make help' to see all available commands ####

.PHONY: help install setup start stop restart logs test lint clean backup restore deploy-k8s deploy-k3d deploy-aws deploy-azure monitor load-test security deploy rollback status

# #### Help Command ####
# #### Shows all available commands with descriptions ####
help:
	@echo "PayFlow - Production-Ready Fintech Microservices"
	@echo "=================================================="
	@echo ""
	@echo "🎯 MANUAL DEPLOYMENT FIRST (Learn by doing):"
	@echo "make install           - Install all dependencies"
	@echo "make start             - Start all services (Docker Compose)"
	@echo "make stop              - Stop all services"
	@echo "make logs              - Show logs"
	@echo "make test              - Run tests"
	@echo "make lint              - Run linting"
	@echo "make clean             - Clean up everything"
	@echo ""
	@echo "🚀 PROGRESSION: Manual → Scripted → Automated"
	@echo "make deploy-k3d        - Deploy to k3d (local K8s) - MANUAL"
	@echo "make deploy-aws        - Deploy to AWS EKS - MANUAL"
	@echo "make deploy-azure      - Deploy to Azure AKS - MANUAL"
	@echo "make deploy            - Blue-Green deployment - MANUAL"
	@echo "make rollback          - Rollback deployment - MANUAL"
	@echo "make status            - Check deployment status - MANUAL"
	@echo ""
	@echo "📊 MONITORING & OPERATIONS:"
	@echo "make monitor           - Start monitoring"
	@echo "make load-test         - Run load tests"
	@echo "make security          - Run security scan"
	@echo "make backup            - Backup databases"
	@echo "make restore           - Restore from backup"

# #### Installation Commands ####
# #### These commands install dependencies and set up the environment ####
install:
	npm run install:all  # Install all Node.js dependencies for all services

setup:
	./scripts/setup.sh  # Run the complete setup script

# #### Service Management Commands ####
# #### These commands start, stop, and manage PayFlow services ####
start:
	docker-compose up -d  # Start all services in the background
	@echo "✅ All services started!"
	@echo "Access: http://localhost"

stop:
	docker-compose down  # Stop all services
	@echo "✅ All services stopped!"

restart:
	docker-compose restart  # Restart all services
	@echo "✅ All services restarted!"

logs:
	docker-compose logs -f  # Show logs from all services (follow mode)

# #### Development Commands ####
# #### These commands help with development and testing ####
test:
	npm run test:all  # Run all tests

lint:
	npm run lint:all  # Run code linting

clean:
	./scripts/cleanup.sh  # Clean up Docker containers, volumes, and logs

# #### Database Commands ####
# #### These commands manage database backups and restores ####
backup:
	./scripts/backup-db.sh  # Create a backup of the PostgreSQL database

restore:
	@read -p "Backup file: " file; ./scripts/restore-db.sh $$file  # Restore database from backup

# #### Deployment Commands ####
# #### These commands deploy PayFlow to different environments ####
deploy-k8s:
	./scripts/deploy-k8s.sh  # Deploy to Kubernetes using the deployment script

deploy-k3d:
	@echo "☸️ Deploying to k3d..."  # Deploy to local Kubernetes using k3d
	@k3d cluster create payflow --port "80:80@loadbalancer" --port "3000:3000@loadbalancer"  # Create k3d cluster
	@kubectl apply -f k8s/complete-deployment.yaml  # Apply Kubernetes manifests
	@echo "✅ Deployed to k3d! Access at http://localhost"

deploy-aws:
	@echo "☁️ Deploying to AWS EKS..."
	@./scripts/deploy-aws.sh

deploy-azure:
	@echo "☁️ Deploying to Azure AKS..."
	@./scripts/deploy-azure.sh

monitor:
	./scripts/monitor.sh

load-test:
	./scripts/load-test.sh

security:
	./scripts/security-scan.sh

deploy:
	@echo "🚀 Blue-Green deployment for $(SERVICE) version $(VERSION)"
	@./scripts/blue-green-deploy.sh $(SERVICE) $(VERSION)

rollback:
	@echo "🔄 Rolling back $(SERVICE) to blue environment"
	@kubectl patch service $(SERVICE)-service -n payflow -p '{"spec":{"selector":{"version":"blue"}}}'

status:
	@echo "📊 Deployment Status for $(SERVICE):"
	@kubectl get deployments -n payflow -l app=$(SERVICE)
	@kubectl get pods -n payflow -l app=$(SERVICE)
	@kubectl get service $(SERVICE)-service -n payflow