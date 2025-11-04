# #### PayFlow Makefile ####
# #### This file provides simple commands for common PayFlow operations ####
# #### Use 'make help' to see all available commands ####

.PHONY: help install start stop restart logs test lint clean deploy-microk8s deploy-k3d deploy-aws deploy-azure monitoring argocd cloudflare status

# #### Help Command ####
# #### Shows all available commands with descriptions ####
help:
	@echo "PayFlow - Production-Ready Fintech Microservices"
	@echo "=================================================="
	@echo ""
	@echo "🎯 DOCKER COMPOSE (Quick Start):"
	@echo "make install           - Install all dependencies"
	@echo "make start             - Start all services (Docker Compose)"
	@echo "make stop              - Stop all services"
	@echo "make restart           - Restart all services"
	@echo "make logs              - Show logs from all services"
	@echo "make test              - Run tests"
	@echo "make lint              - Run linting"
	@echo "make clean             - Clean up Docker containers and volumes"
	@echo ""
	@echo "🚀 KUBERNETES DEPLOYMENT:"
	@echo "make deploy-microk8s   - Complete deployment to MicroK8s (recommended)"
	@echo "                       - Includes: MicroK8s setup, images, monitoring, ArgoCD, Cloudflare"
	@echo "make deploy-k3d        - Deploy to k3d (local K8s)"
	@echo "make deploy-aws        - Deploy to AWS EKS (see docs/aws-deployment.md)"
	@echo "make deploy-azure      - Deploy to Azure AKS (see docs/azure-deployment.md)"
	@echo ""
	@echo "📊 MONITORING & OBSERVABILITY:"
	@echo "make monitoring       - Check monitoring stack status (Prometheus, Grafana, alert rules)"
	@echo "make argocd            - Get ArgoCD admin password and access URL"
	@echo "make cloudflare        - Check Cloudflare tunnel status"
	@echo "make status            - Check deployment status (all namespaces)"
	@echo ""
	@echo "💡 TIP: Use 'make deploy-microk8s' for complete production-ready deployment!"

# #### Installation Commands ####
# #### These commands install dependencies and set up the environment ####
install:
	@echo "📦 Installing dependencies for all services..."
	@cd services/api-gateway && npm install
	@cd services/auth-service && npm install
	@cd services/wallet-service && npm install
	@cd services/transaction-service && npm install
	@cd services/notification-service && npm install
	@cd services/frontend && npm install
	@echo "✅ All dependencies installed!"

# #### Service Management Commands ####
# #### These commands start, stop, and manage PayFlow services ####
start:
	@echo "🚀 Starting PayFlow with Docker Compose..."
	docker-compose up -d
	@echo "✅ All services started!"
	@echo ""
	@echo "🌐 Access URLs:"
	@echo "  • Frontend: http://localhost"
	@echo "  • API Gateway: http://localhost:3000"
	@echo "  • API Docs: http://localhost:3000/api-docs"
	@echo "  • Grafana: http://localhost:3006 (admin/admin)"
	@echo "  • Prometheus: http://localhost:9090"
	@echo "  • RabbitMQ: http://localhost:15672 (payflow/payflow123)"

stop:
	@echo "🛑 Stopping all services..."
	docker-compose down
	@echo "✅ All services stopped!"

restart:
	@echo "🔄 Restarting all services..."
	docker-compose restart
	@echo "✅ All services restarted!"

logs:
	@echo "📋 Showing logs from all services (Ctrl+C to exit)..."
	docker-compose logs -f

# #### Development Commands ####
# #### These commands help with development and testing ####
test:
	@echo "🧪 Running tests..."
	@echo "⚠️  Run tests manually per service: cd services/<service> && npm test"

lint:
	@echo "🔍 Running linter..."
	@echo "⚠️  Run linting manually per service: cd services/<service> && npm run lint"

clean:
	@echo "🧹 Cleaning up Docker resources..."
	docker-compose down -v
	docker system prune -f
	@echo "✅ Cleanup complete!"

# #### Kubernetes Deployment Commands ####
# #### These commands deploy PayFlow to Kubernetes environments ####

deploy-microk8s:
	@echo "🚀 Complete PayFlow Deployment to MicroK8s"
	@echo "=========================================="
	@echo "This will:"
	@echo "  • Set up MicroK8s VM (if needed)"
	@echo "  • Enable all addons (DNS, Ingress, MetalLB, etc.)"
	@echo "  • Build and load Docker images"
	@echo "  • Deploy all services"
	@echo "  • Deploy monitoring (Prometheus, Grafana, alert rules)"
	@echo "  • Deploy ArgoCD"
	@echo "  • Deploy Cloudflare Tunnel (if configured)"
	@echo ""
	@read -p "Continue? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@./scripts/deploy-payflow.sh

deploy-k3d:
	@echo "☸️  Deploying to k3d (local Kubernetes)..."
	@echo "⚠️  Note: k3d deployment is manual. See docs/k3d-deployment.md"
	@k3d cluster create payflow --port "80:80@loadbalancer" --port "3000:3000@loadbalancer" --port "3006:3006@loadbalancer" --port "9090:9090@loadbalancer" || true
	@kubectl apply -k k8s/
	@echo "✅ Deployed to k3d! Access at http://localhost"

deploy-aws:
	@echo "☁️  Deploying to AWS EKS..."
	@echo "⚠️  Note: AWS deployment requires AWS CLI and credentials"
	@echo "See docs/aws-deployment.md for manual steps"

deploy-azure:
	@echo "☁️  Deploying to Azure AKS..."
	@echo "⚠️  Note: Azure deployment requires Azure CLI and credentials"
	@echo "See docs/azure-deployment.md for manual steps"

# #### Monitoring & Observability Commands ####
# #### These commands help monitor and observe the system ####

monitoring:
	@echo "📊 Monitoring Stack Status"
	@echo "========================="
	@if command -v kubectl &> /dev/null && kubectl get namespace monitoring &> /dev/null 2>&1; then \
		echo ""; \
		echo "📈 Prometheus:"; \
		kubectl get pods -n monitoring -l app=prometheus || echo "  Prometheus not found"; \
		echo ""; \
		echo "📊 Grafana:"; \
		kubectl get pods -n monitoring -l app=grafana || echo "  Grafana not found"; \
		echo ""; \
		echo "🔔 Alert Rules:"; \
		kubectl get configmap prometheus-rules -n monitoring &> /dev/null && echo "  ✅ Alert rules deployed" || echo "  ⚠️  Alert rules not found"; \
		echo ""; \
		echo "🌐 Access URLs:"; \
		GRAFANA_IP=$$(kubectl get svc grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending"); \
		PROM_IP=$$(kubectl get svc prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending"); \
		echo "  • Grafana: http://$$GRAFANA_IP:3000 (or http://grafana.payflow.local)"; \
		echo "  • Prometheus: http://$$PROM_IP:9090 (or http://prometheus.payflow.local)"; \
		echo "  • Default Grafana login: admin/admin"; \
	else \
		echo "⚠️  Kubernetes cluster not accessible or monitoring namespace not found"; \
		echo "   Make sure kubectl is configured and monitoring is deployed"; \
		echo "   Run: make deploy-microk8s"; \
	fi

argocd:
	@echo "🚢 ArgoCD Status"
	@echo "==============="
	@if command -v kubectl &> /dev/null && kubectl get namespace argocd &> /dev/null 2>&1; then \
		echo ""; \
		echo "📦 ArgoCD Pods:"; \
		kubectl get pods -n argocd || echo "  ArgoCD not found"; \
		echo ""; \
		echo "🔑 Getting admin password..."; \
		PASSWORD=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d); \
		if [ -n "$$PASSWORD" ]; then \
			echo "  ✅ Admin Password: $$PASSWORD"; \
		else \
			echo "  ⚠️  Password not available (may have been changed)"; \
		fi; \
		echo ""; \
		echo "🌐 Access URLs:"; \
		echo "  • Local: http://argocd.payflow.local"; \
		echo "  • Production: https://argocd.gameapp.games"; \
		echo "  • Username: admin"; \
		echo ""; \
		echo "📋 Applications:"; \
		kubectl get applications -n argocd 2>/dev/null || echo "  No applications found"; \
	else \
		echo "⚠️  ArgoCD not deployed or not accessible"; \
		echo "   Run: make deploy-microk8s"; \
	fi

cloudflare:
	@echo "☁️  Cloudflare Tunnel Status"
	@echo "=========================="
	@if command -v kubectl &> /dev/null && kubectl get deployment cloudflare-tunnel -n payflow &> /dev/null 2>&1; then \
		echo ""; \
		echo "🌐 Tunnel Pod Status:"; \
		kubectl get pods -n payflow -l app=cloudflare-tunnel; \
		echo ""; \
		echo "📋 Recent Logs:"; \
		kubectl logs -n payflow -l app=cloudflare-tunnel --tail=10 || echo "  No logs available"; \
		echo ""; \
		echo "🔗 Production URLs:"; \
		echo "  • Frontend: https://gameapp.games"; \
		echo "  • API: https://app.gameapp.games"; \
		echo "  • Grafana: https://grafana.gameapp.games"; \
		echo "  • Prometheus: https://prometheus.gameapp.games"; \
		echo "  • ArgoCD: https://argocd.gameapp.games"; \
	else \
		echo "⚠️  Cloudflare tunnel not deployed"; \
		echo "   To deploy:"; \
		echo "   1. Create k8s/secrets/cloudflare-tunnel-secret.yaml with your tunnel token"; \
		echo "   2. Run: kubectl apply -f k8s/deployments/cloudflare-tunnel.yaml"; \
		echo "   Or run: make deploy-microk8s (includes tunnel if secret exists)"; \
	fi

# #### Status & Information Commands ####
# #### These commands show deployment status ####

status:
	@echo "📊 PayFlow Deployment Status"
	@echo "=========================="
	@if command -v kubectl &> /dev/null; then \
		echo ""; \
		echo "📦 PayFlow Namespace:"; \
		kubectl get pods -n payflow 2>/dev/null || echo "  PayFlow namespace not found"; \
		echo ""; \
		echo "📊 Monitoring Namespace:"; \
		kubectl get pods -n monitoring 2>/dev/null || echo "  Monitoring namespace not found"; \
		echo ""; \
		echo "🚢 ArgoCD Namespace:"; \
		kubectl get pods -n argocd 2>/dev/null || echo "  ArgoCD namespace not found"; \
		echo ""; \
		echo "🌐 Services:"; \
		kubectl get svc -n payflow 2>/dev/null || echo "  No services found"; \
	else \
		echo "⚠️  kubectl not found or not configured"; \
		echo "   Make sure kubectl is installed and KUBECONFIG is set"; \
		echo "   Or use Docker Compose: make start"; \
	fi
