# PayFlow Troubleshooting Guide

## 🚨 **Common Issues and Solutions**

This guide covers the most common issues you'll encounter when deploying PayFlow and how to fix them.

---

## 🐳 **Docker Issues**

### **Issue: Colima VM Frozen or Unresponsive**
**Symptoms:**
- Docker commands hang indefinitely
- `colima status` doesn't respond
- Image builds freeze

**Root Cause:**
- Colima VM ran out of resources (memory/disk)
- Mac went to sleep while Docker was running
- Force-quit terminal during build process

**Solution:**
```bash
# Force-kill Colima processes
pkill -9 colima
pkill -9 qemu

# Delete corrupted VM
colima delete --force

# If that hangs, manually remove Colima data
rm -rf ~/.colima/default
rm -rf ~/.colima/_lima

# Start fresh with proper resources
colima start --cpu 4 --memory 8 --vm-type vz --mount-type virtiofs

# Prevention: Always use adequate memory (minimum 8GB)
```

### **Issue: Docker Credentials Error with Colima**
**Symptoms:**
```bash
# Error: exec: "docker-credential-osxkeychain": executable file not found
```

**Root Cause:**
- Docker trying to use credential helper when pulling images
- Colima doesn't need credential helper for local development

**Solution:**
```bash
# Disable credential helper temporarily
mkdir -p ~/.docker
echo '{"credsStore":""}' > ~/.docker/config.json

# Or explicitly pull images into Colima's cache first
docker pull nginx:alpine
docker pull node:18-alpine
```

### **Issue: Container Build Failures - npm ci vs npm install**
**Symptoms:**
```bash
# Error: npm ci can only install with an existing package-lock.json
# Build hangs or fails
```

**Root Cause:**
- `package-lock.json` excluded by `.dockerignore`
- Lockfile out of sync with `package.json`
- Network issues causing `npm ci` to hang

**Solution:**
```bash
# Ensure .dockerignore doesn't exclude package-lock.json
# Update .dockerignore:
# Remove: package-lock.json
# Keep: node_modules, .git, etc.

# Regenerate lockfiles
cd services/<service-name>
rm package-lock.json
npm install

# Use npm ci for reproducible builds (recommended)
# Use npm install only if lockfile issues persist
```

### **Issue: Image Builds Taking Too Long**
**Symptoms:**
- Docker builds take 5-10+ minutes
- Every small change triggers full rebuild

**Root Cause:**
- Poor layer caching strategy
- Dependencies reinstalled on every build
- Large build context

**Solution:**
```dockerfile
# Optimized Dockerfile pattern:
# 1. Copy package files first (for better caching)
COPY package*.json ./
RUN npm ci

# 2. Copy source code (only rebuilds when code changes)
COPY . .

# 3. Use multi-stage builds
FROM node:18-alpine AS builder
# ... build stage ...

FROM node:18-alpine
COPY --from=builder /app/dist ./dist
# ... production stage ...
```

### **Issue: Port Already Allocated**
**Symptoms:**
```bash
# Error: Bind for 0.0.0.0:3001 failed: port is already allocated
```

**Solution:**
```bash
# Find process using port
lsof -i :3001

# Kill process
kill -9 <PID>

# Or stop conflicting containers
docker stop $(docker ps -q --filter "publish=3001")
```

---

## ☸️ **MicroK8s Issues**

### **Issue: LoadBalancer Services Stuck in Pending**
**Symptoms:**
```bash
# kubectl get svc
api-gateway   LoadBalancer   10.152.183.214   <pending>   80:31377/TCP
```

**Root Cause:**
- MetalLB addon not enabled in MicroK8s
- LoadBalancer needs IP range allocation

**Solution:**
```bash
# Check VM network (usually 10.1.254.x)
multipass info microk8s-vm | grep IPv4

# Enable MetalLB with IP range from same subnet
multipass exec microk8s-vm -- microk8s enable metallb:10.1.254.100-10.1.254.150

# Verify
kubectl get pods -n metallb-system
kubectl get svc | grep LoadBalancer
# Should show actual IP instead of <pending>
```

**Why:** MicroK8s doesn't include a LoadBalancer implementation by default. MetalLB provides Layer 2 load balancing for local clusters.

### **Issue: Ingress Not Routing Traffic**
**Symptoms:**
- Services return 404 or connection refused
- Ingress controller not responding

**Root Cause:**
- Nginx ingress addon not enabled
- Ingress class mismatch
- DNS not resolving

**Solution:**
```bash
# Enable ingress addon
multipass exec microk8s-vm -- microk8s enable ingress

# Verify ingress controller
kubectl get pods -n ingress

# Check ingress class matches
kubectl get ingress -n <namespace>
# Should show ingressClassName: nginx

# Add to /etc/hosts (replace with actual LoadBalancer IP)
echo "10.1.254.100 api.payflow.local www.payflow.local" | sudo tee -a /etc/hosts
```

### **Issue: MicroK8s VM Not Starting**
**Symptoms:**
```bash
# Error: multipass start microk8s-vm fails
# or: microk8s status shows not running
```

**Solution:**
```bash
# Check VM status
multipass list

# Start VM manually
multipass start microk8s-vm

# Check MicroK8s status
multipass exec microk8s-vm -- microk8s status

# Restart MicroK8s if needed
multipass exec microk8s-vm -- microk8s stop
multipass exec microk8s-vm -- microk8s start
```

### **Issue: Storage/Registry Addon Failures**
**Symptoms:**
- PVCs stuck in Pending
- Can't pull local images

**Solution:**
```bash
# Enable storage (for PVCs)
multipass exec microk8s-vm -- microk8s enable storage

# Enable registry (for local image builds)
multipass exec microk8s-vm -- microk8s enable registry

# Verify addons
multipass exec microk8s-vm -- microk8s status
```

---

## 🔧 **Kubernetes Issues**

### **Issue: Service Port Mismatch (80 vs 8080)**
**Symptoms:**
```bash
# Ingress returns 404
# Service accessible via port-forward but not ingress
```

**Root Cause:**
- Confusion between service port and container port
- Service port 80 forwards to targetPort 8080
- Ingress pointing to wrong port number

**Solution:**
```bash
# Check service configuration
kubectl get svc <service-name> -n <namespace> -o yaml
# Look for: port: 80, targetPort: 8080

# Ingress should point to SERVICE port (80), not targetPort
# Correct ingress configuration:
spec:
  backend:
    service:
      name: argocd-server
      port:
        number: 80  # Service port, NOT 8080
```

**Why:** Kubernetes Services act as load balancers. The service exposes port 80 externally, which forwards to container port 8080. Ingress routes to the service port, not the container port directly.

### **Issue: ConfigMap Changes Not Applied**
**Symptoms:**
- Updated ConfigMap but pods still using old values
- Environment variables not updating

**Root Cause:**
- Pods don't automatically restart when ConfigMap changes
- Environment variables loaded at pod startup
- Deployment needs restart to pick up changes

**Solution:**
```bash
# Restart deployment to pick up ConfigMap changes
kubectl rollout restart deployment <deployment-name> -n <namespace>

# Verify ConfigMap update
kubectl get configmap <configmap-name> -n <namespace> -o yaml

# Check pod environment
kubectl exec <pod-name> -n <namespace> -- env | grep <VAR_NAME>
```

### **Issue: Pod Stuck in CrashLoopBackOff**
**Symptoms:**
```bash
# kubectl get pods
NAME                              READY   STATUS             RESTARTS
api-gateway-xxx                   0/1     CrashLoopBackOff   5
```

**Solution:**
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Missing environment variables (check ConfigMap/Secrets)
# - Wrong image tag
# - Resource limits too low
# - Health check failing (check probes)

# Fix and restart
kubectl rollout restart deployment <deployment-name> -n <namespace>
```

### **Issue: Ingress SSL Certificate Errors**
**Symptoms:**
```bash
# Browser shows: ERR_CERT_AUTHORITY_INVALID
# curl: SSL certificate problem: self-signed certificate
```

**Root Cause:**
- Self-signed certificates for local development
- Cert-manager ClusterIssuer not configured
- Certificate not ready

**Solution:**
```bash
# Check certificate status
kubectl get certificate -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# For local development, accept self-signed warning
# Or configure cert-manager with proper issuer

# Verify certificate secret exists
kubectl get secret <tls-secret-name> -n <namespace>
```

---

## 🚢 **ArgoCD Issues**

### **Issue: Redirect Loop (ERR_TOO_MANY_REDIRECTS)**
**Symptoms:**
- Browser shows infinite redirect loop
- `curl` returns 307 redirects repeatedly
- ArgoCD login page never loads

**Root Cause:**
- ArgoCD configured for HTTPS but behind TLS-terminating ingress
- SSL redirect annotations causing double redirects
- ConfigMap configuration mismatch

**Solution:**
```bash
# 1. Configure ArgoCD for insecure mode (behind ingress)
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true","url":"https://argocd.payflow.local"}}'

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# 2. Remove SSL redirect from ingress (let ArgoCD handle it)
# In ingress annotations, remove or set:
# nginx.ingress.kubernetes.io/ssl-redirect: "false"

# 3. Restart ArgoCD server
kubectl rollout restart deployment argocd-server -n argocd
```

**Why:** When ArgoCD runs behind a TLS-terminating ingress, it receives HTTP traffic internally. The `server.insecure: "true"` tells ArgoCD to accept HTTP connections, preventing redirect loops.

### **Issue: ArgoCD UI Returns 404**
**Symptoms:**
- `curl` returns HTTP 404
- Browser shows "404 page not found"
- API endpoints accessible but UI not loading

**Root Cause:**
- ArgoCD installed with missing static assets
- Static assets directory not available (`/shared/app` missing)
- ArgoCD not properly configured for ingress access

**Solution:**
```bash
# Reinstall ArgoCD from official manifests
kubectl delete namespace argocd --wait=true

# Recreate and install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods
kubectl wait --for=condition=ready pod -n argocd --all --timeout=300s

# Configure for ingress
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true","url":"https://argocd.payflow.local"}}'

# Restart server
kubectl rollout restart deployment argocd-server -n argocd
```

**Why:** Fresh install ensures embedded static assets are available. ArgoCD v3.1.9+ embeds UI assets, eliminating need for `/shared/app` directory when properly installed.

### **Issue: Certificate Conflict with Cert-Manager**
**Symptoms:**
```bash
# kubectl get certificate
NAME         READY   SECRET       AGE
argocd-tls   False   argocd-tls   5m

# kubectl describe certificate shows:
# "Secret was issued for 'argocd-tls-cert'. If this message is not transient,
#  you might have two conflicting Certificates pointing to the same secret."
```

**Root Cause:**
- Multiple Certificate resources targeting same secret name
- Old certificate not deleted before creating new one

**Solution:**
```bash
# Delete all conflicting certificates
kubectl delete certificate -n argocd --all

# Wait a few seconds
sleep 5

# Apply new certificate issuer
kubectl apply -f k8s/argocd/argocd-certificate-issuer.yaml

# Wait for certificate to be ready
kubectl wait --for=condition=ready certificate argocd-tls -n argocd --timeout=120s
```

### **Issue: ArgoCD ConfigMap Confusion (argocd-cm vs argocd-cmd-params-cm)**
**Symptoms:**
- Updated ConfigMap but changes not taking effect
- Server still redirecting despite configuration

**Root Cause:**
- ArgoCD reads `server.insecure` from `argocd-cmd-params-cm`, not `argocd-cm`
- Two ConfigMaps serve different purposes:
  - `argocd-cm`: General server configuration
  - `argocd-cmd-params-cm`: Server startup parameters

**Solution:**
```bash
# Update BOTH ConfigMaps
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true","url":"https://argocd.payflow.local"}}'

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Restart server to apply argocd-cmd-params-cm changes
kubectl rollout restart deployment argocd-server -n argocd
```

**Why:** ArgoCD architecture separates configuration concerns. Server command-line parameters (like `--insecure`) come from `argocd-cmd-params-cm`, while runtime configuration (like `url`) comes from `argocd-cm`.

### **Note: gRPC-Web vs gRPC for ArgoCD**
**Why we don't use standard gRPC annotations:**
- ArgoCD UI uses **gRPC-Web** (not standard gRPC)
- gRPC-Web works over HTTP/1.1, compatible with standard ingress
- Standard gRPC requires HTTP/2 and special ingress configuration
- ArgoCD's `server.enable.grpc.web: "true"` enables gRPC-Web support
- No special ingress annotations needed - standard HTTP backend protocol works

---

## 🔧 **Service Health Issues**

### **Issue: Service shows as unhealthy**
```bash
# Check service status
docker-compose ps

# Check service logs
docker-compose logs <service-name>

# Check health endpoint
curl http://localhost:<port>/health
```

**Common Causes & Solutions:**

#### **Health check using curl instead of wget**
```bash
# Problem: curl not available in Alpine images
# Solution: Use wget in health checks
healthcheck:
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3001/health"]
```

#### **Missing dependencies**
```bash
# Check if all dependencies are installed
docker-compose exec <service> npm list

# Rebuild service with dependencies
docker-compose build <service>
docker-compose up -d <service>
```

### **Issue: Native module compilation errors**
```bash
# Error: Error loading shared library bcrypt_lib.node: Exec format error
```

**Solutions:**
```bash
# Option 1: Use bcryptjs (pure JavaScript)
npm uninstall bcrypt
npm install bcryptjs

# Option 2: Install build tools in Dockerfile
RUN apk add --no-cache python3 make g++
RUN npm rebuild bcrypt
```

---

## 🗄️ **Database Issues**

### **Issue: Database connection failed**
```bash
# Error: connection to server at "postgres" (172.20.0.2), port 5432 failed
```

**Solutions:**
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres

# Check database exists
docker-compose exec postgres psql -U payflow -d payflow -c "\l"
```

### **Issue: Migration failures**
```bash
# Error: relation "users" already exists
```

**Solutions:**
```bash
# Check current schema
docker-compose exec postgres psql -U payflow -d payflow -c "\dt"

# Drop and recreate database
docker-compose exec postgres psql -U payflow -c "DROP DATABASE payflow;"
docker-compose exec postgres psql -U payflow -c "CREATE DATABASE payflow;"

# Re-run migrations
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql
```

---

## 🔐 **Authentication Issues**

### **Issue: HTTP 429 Too Many Requests**
```bash
# Error: Too many authentication attempts
```

**Solutions:**
```bash
# Check rate limiting configuration
grep -r "rateLimit" services/api-gateway/server.js

# Flush Redis cache
docker-compose exec redis redis-cli FLUSHALL

# Restart API Gateway
docker-compose restart api-gateway

# For development, increase rate limits
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000, // Increase from 5 to 1000
  skipSuccessfulRequests: true
});
```

### **Issue: JWT token invalid**
```bash
# Error: jwt malformed
```

**Solutions:**
```bash
# Check JWT secret is set
echo $JWT_SECRET

# Check token format
echo "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." | base64 -d

# Regenerate token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## 📊 **Monitoring Issues**

### **Issue: Prometheus targets down**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

**Solutions:**
```bash
# Check if services expose metrics
curl http://localhost:3000/metrics
curl http://localhost:3001/metrics

# Restart Prometheus
docker-compose restart prometheus

# Check Prometheus configuration
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml
```

### **Issue: Grafana dashboard not loading**
```bash
# Check Grafana status
curl http://localhost:3006/api/health
```

**Solutions:**
```bash
# Check Grafana logs
docker-compose logs grafana

# Restart Grafana
docker-compose restart grafana

# Check datasource configuration
curl -u admin:admin http://localhost:3006/api/datasources
```

### **Issue: Alert rules not loading**
```bash
# Check alert rules
curl http://localhost:9090/api/v1/rules
```

**Solutions:**
```bash
# Check alert file is mounted
docker-compose exec prometheus ls -la /etc/prometheus/alerts.yml

# Fix Prometheus configuration
# In prometheus.yml, ensure:
rule_files:
  - '/etc/prometheus/alerts.yml'

# Restart Prometheus
docker-compose restart prometheus
```

---

## 🌐 **Frontend Issues**

### **Issue: Frontend not loading**
```bash
# Check frontend container
docker-compose ps frontend
```

**Solutions:**
```bash
# Check frontend logs
docker-compose logs frontend

# Check if API Gateway is accessible from frontend
docker-compose exec frontend curl http://api-gateway:3000/health

# Restart frontend
docker-compose restart frontend
```

### **Issue: CORS errors**
```bash
# Error: Access to fetch at 'http://localhost:3000/api/auth/login' from origin 'http://localhost' has been blocked by CORS policy
```

**Solutions:**
```bash
# Check CORS configuration in API Gateway
grep -r "cors" services/api-gateway/server.js

# Update CORS settings
app.use(cors({
  origin: ['http://localhost', 'http://localhost:80'],
  credentials: true
}));
```

---

## 🔄 **Message Queue Issues**

### **Issue: RabbitMQ connection failed**
```bash
# Error: connection to server at "rabbitmq" (172.20.0.3), port 5672 failed
```

**Solutions:**
```bash
# Check RabbitMQ status
docker-compose ps rabbitmq

# Check RabbitMQ logs
docker-compose logs rabbitmq

# Access RabbitMQ management
open http://localhost:15672
# Login: payflow / payflow123

# Restart RabbitMQ
docker-compose restart rabbitmq
```

---

## 🚀 **Performance Issues**

### **Issue: High memory usage**
```bash
# Check memory usage
docker stats

# Check Prometheus metrics
curl http://localhost:9090/api/v1/query?query=process_resident_memory_bytes
```

**Solutions:**
```bash
# Restart services
docker-compose restart

# Check for memory leaks in logs
docker-compose logs | grep -i "memory\|leak"

# Scale services
docker-compose up -d --scale transaction-service=2
```

### **Issue: Slow response times**
```bash
# Check response time metrics
curl http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))
```

**Solutions:**
```bash
# Check database performance
docker-compose exec postgres psql -U payflow -d payflow -c "SELECT * FROM pg_stat_activity;"

# Check Redis performance
docker-compose exec redis redis-cli INFO stats

# Check RabbitMQ queues
curl http://localhost:15672/api/queues
```

---

## 🔍 **Debugging Commands**

### **General Debugging**
```bash
# Check all service status
docker-compose ps

# Check service logs
docker-compose logs <service-name>

# Check service health
curl http://localhost:<port>/health

# Check service metrics
curl http://localhost:<port>/metrics

# Check network connectivity
docker-compose exec <service> ping <other-service>

# Check DNS resolution
docker-compose exec <service> nslookup <other-service>
```

### **Database Debugging**
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U payflow -d payflow

# Check tables
\dt

# Check users
SELECT * FROM users LIMIT 5;

# Check transactions
SELECT * FROM transactions LIMIT 5;

# Check database size
SELECT pg_size_pretty(pg_database_size('payflow'));
```

### **Redis Debugging**
```bash
# Connect to Redis
docker-compose exec redis redis-cli

# Check keys
KEYS *

# Check memory usage
INFO memory

# Check connected clients
INFO clients

# Flush all data
FLUSHALL
```

### **Monitoring Debugging**
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Prometheus rules
curl http://localhost:9090/api/v1/rules

# Check Grafana datasources
curl -u admin:admin http://localhost:3006/api/datasources

# Check AlertManager alerts
curl http://localhost:9093/api/v2/alerts
```

---

## 🆘 **Emergency Recovery**

### **Complete System Reset**
```bash
# Stop all services
docker-compose down

# Remove all volumes (WARNING: This deletes all data)
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Clean up Docker system
docker system prune -a

# Start fresh
docker-compose up -d
```

### **Partial Service Reset**
```bash
# Reset specific service
docker-compose stop <service>
docker-compose rm <service>
docker-compose build <service>
docker-compose up -d <service>
```

### **Database Reset**
```bash
# Stop services that depend on database
docker-compose stop api-gateway auth-service wallet-service transaction-service notification-service

# Reset database
docker-compose stop postgres
docker-compose rm postgres
docker-compose up -d postgres

# Wait for database to be ready
sleep 10

# Re-run migrations
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V1__initial_schema.sql
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V2__add_indexes.sql
docker-compose exec postgres psql -U payflow -d payflow -f /migrations/V3__add_2fa.sql

# Restart services
docker-compose up -d
```

---

## 📞 **Getting Help**

### **Log Collection for Support**
```bash
# Collect all logs
docker-compose logs > payflow-logs.txt

# Collect system info
docker --version > system-info.txt
docker-compose --version >> system-info.txt
docker-compose ps >> system-info.txt

# Collect configuration
cp docker-compose.yml payflow-config.yml
cp -r monitoring/ payflow-monitoring/
```

### **Useful Resources**
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)

---

## 🎯 **Prevention Tips**

1. **Always check service health** before proceeding to next steps
2. **Monitor logs** during deployment
3. **Use health checks** in docker-compose.yml
4. **Test each service individually** before starting all services
5. **Keep backups** of important data
6. **Use version control** for configuration changes
7. **Document any custom changes** you make

Remember: **Manual deployment first, then automation!** This troubleshooting guide helps you understand what's happening under the hood.

---

## 🕐 **Transaction Auto-Reversal Issues**

### **Issue: Pending transactions stuck and not completing**

**Symptoms:**
- Transactions stuck in "PENDING" status
- Balance not updating
- New transactions failing with "Insufficient funds"
- No notifications being sent

**Root Cause:**
- RabbitMQ authentication failure prevented transaction processing
- Pending transactions holding funds indefinitely

**Solutions:**

#### **1. Fix RabbitMQ Credentials**
```bash
# Update RABBITMQ_URL in ConfigMap to include credentials
kubectl edit configmap app-config -n payflow

# Change from:
RABBITMQ_URL: "amqp://rabbitmq:5672"

# To:
RABBITMQ_URL: "amqp://payflow:payflow123@rabbitmq:5672"

# Restart services
kubectl rollout restart deployment/transaction-service deployment/notification-service -n payflow
```

#### **2. Manual Transaction Reversal**
```bash
# Connect to PostgreSQL
kubectl exec -n payflow $(kubectl get pod -n payflow -l app=postgres -o jsonpath='{.items[0].metadata.name}') -- psql -U payflow -d payflow

# Reverse stuck pending transactions
UPDATE transactions 
SET status = 'FAILED', 
    error_message = 'Transaction timeout - funds released',
    completed_at = CURRENT_TIMESTAMP
WHERE status = 'PENDING' 
  AND (from_user_id = 'user-id' OR to_user_id = 'user-id');

# Check wallet balance
SELECT user_id, balance FROM wallets WHERE user_id = 'user-id';
```

#### **3. Auto-Reversal CronJob**
PayFlow includes a Kubernetes CronJob that automatically reverses stuck transactions after 1 minute:

**Configuration:**
- **File:** `k8s/jobs/transaction-timeout.yaml`
- **Schedule:** Runs every minute
- **Timeout:** 1 minute
- **Action:** Updates PENDING transactions to FAILED

**Deploy:**
```bash
kubectl apply -f k8s/jobs/transaction-timeout.yaml

# Check status
kubectl get cronjob transaction-timeout-handler -n payflow

# View recent jobs
kubectl get jobs -n payflow | grep transaction-timeout

# Check logs
kubectl logs -n payflow job/transaction-timeout-handler-XXXXXXXX
```

**Environment Variables Used:**
- `PGDATABASE` - Database name from ConfigMap
- `PGUSER` - Username from Secret
- `PGPASSWORD` - Password from Secret
- **NO secrets exposed in configuration files**

**How It Works:**
1. Runs every minute via Kubernetes CronJob
2. Finds pending transactions older than 1 minute
3. Updates them to FAILED status with error message
4. Releases held funds back to user balance
5. Prevents "insufficient funds" errors from stuck transactions

This mimics real banking behavior where stuck transactions are automatically reversed after timeout.

---

## 🔐 **Security Notes**

### **Secret Management**
- All passwords stored in Kubernetes Secrets (encrypted at rest)
- Environment variables reference Secrets via `secretKeyRef`
- No plaintext credentials in ConfigMaps or YAML files
- PostgreSQL uses `PGUSER` and `PGPASSWORD` environment variables

### **Why PGDATABASE vs POSTGRES_DB**
- `PGDATABASE` is the official PostgreSQL environment variable
- Avoids conflicts with other database environment variables
- PostgreSQL tools automatically use `PG*` prefixed variables
- No need to rename existing app logic variables

---

