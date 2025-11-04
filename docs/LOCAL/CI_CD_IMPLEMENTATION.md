# CI/CD Implementation Guide

## 🎯 **Overview**

This guide explains how PayFlow implements CI/CD for both **local** (MicroK8s/Colima) and **cloud** (AWS/Azure) deployments.

**📌 We have two separate pipelines:**
- **`cicd-local.yml`** - For LOCAL deployment to MicroK8s/Colima
- **`ci-cd.yml`** - For CLOUD deployment to AWS/Azure/GCP

---

## 📋 **Table of Contents**

1. [Local CI/CD Pipeline](#local-cicd-pipeline)
2. [Cloud CI/CD Pipeline](#cloud-cicd-pipeline)
3. [Required Secrets](#required-secrets)
4. [Self-Hosted Runner Setup](#self-hosted-runner-setup)

---

## 🖥️ **Local CI/CD Pipeline**

### **Why Local First?**

We chose to implement local CI/CD first because:
- ✅ **Learn before cloud** - Master Kubernetes locally before cloud costs
- ✅ **Fast iteration** - No waiting for cloud builds/deployments
- ✅ **Cost-effective** - Free to run locally vs cloud charges
- ✅ **Production-like** - MicroK8s is real Kubernetes, not a simulator
- ✅ **Same patterns** - What works locally works in cloud

### **Our Local Stack Choice**

#### **MicroK8s** (not k3d or Docker Desktop)
**Why MicroK8s?**
- ✅ **Real Kubernetes** - Same as production (not a simulator)
- ✅ **Complete addons** - DNS, Ingress, Storage, LoadBalancer, Registry built-in
- ✅ **Production patterns** - MetalLB for LoadBalancer (like cloud)
- ✅ **Easy management** - One command to enable addons
- ✅ **Lightweight** - Runs on Mac via Multipass VM

**vs k3d:**
- k3d is great but uses k3s (different from standard Kubernetes)
- MicroK8s uses actual Kubernetes (exact same as cloud)

**vs Docker Desktop:**
- Docker Desktop Kubernetes is heavier
- MicroK8s is more focused and production-like

#### **Colima** (not Docker Desktop)
**Why Colima?**
- ✅ **Free** - No Docker Desktop subscription needed
- ✅ **Lightweight** - Uses macOS virtualization efficiently
- ✅ **CLI-friendly** - Better for automation and scripts
- ✅ **Resource control** - Easier to manage CPU/memory limits

#### **Kustomize** (not Helm)
**Why Kustomize?**
- ✅ **Native Kubernetes** - Built into kubectl
- ✅ **No server needed** - Works locally without Tiller
- ✅ **Git-friendly** - YAML files in version control
- ✅ **Simple** - Easier for beginners to understand

#### **Understanding Kustomize Base and Overlays**

**What is BASE?**
- **Base** = Shared configuration that ALL environments use
- Contains all your services (api-gateway, auth-service, etc.)
- Same configuration structure for everyone
- No environment-specific values
- Think of it as: "The master blueprint"

**What is an OVERLAY?**
- **Overlay** = Environment-specific changes on top of base
- You have 3 overlays:
  - `k8s/overlays/local/` → For MicroK8s (local)
  - `k8s/overlays/aws/` → For AWS EKS
  - `k8s/overlays/azure/` → For Azure AKS
- Each overlay:
  - References the base (`resources: - ../../base`)
  - Changes only what's different for that environment

**How They Work Together:**

**Example: Your API Gateway Image**

Base manifest (same for everyone):
```yaml
# k8s/deployments/api-gateway.yaml
image: payflow/api-gateway:latest
imagePullPolicy: Never
```

Local overlay (changes it):
```yaml
# k8s/overlays/local/kustomization.yaml
images:
  - name: payflow/api-gateway
    newName: payflow/api-gateway  # Stays same (local)
    
patchesStrategicMerge:
  - patches/image-pull-policy.yaml  # Keeps imagePullPolicy: Never
```

AWS overlay (changes it differently):
```yaml
# k8s/overlays/aws/kustomization.yaml
images:
  - name: payflow/api-gateway
    newName: 334091769766.dkr.ecr.us-east-1.amazonaws.com/payflow/api-gateway  # ECR URL!
    
patchesStrategicMerge:
  - patches/image-pull-policy.yaml  # Changes to imagePullPolicy: IfNotPresent
```

**What Happens When You Deploy?**

When you run:
```bash
kubectl apply -k k8s/overlays/local
```

Kustomize does this:
1. Reads base → Gets all your services
2. Reads local overlay → Gets local-specific changes
3. Merges them together → Creates final configuration
4. Applies to Kubernetes

**Result:**
- **Base**: `image: payflow/api-gateway:latest`
- **Overlay**: `newName: payflow/api-gateway` (same)
- **Final**: `image: payflow/api-gateway:latest` (for local)

**For AWS:**
- **Base**: `image: payflow/api-gateway:latest`
- **Overlay**: `newName: 334091769766.dkr.ecr...` (ECR URL)
- **Final**: `image: 334091769766.dkr.ecr.../payflow/api-gateway:latest` (for AWS)

**Why Use This?**

**Without Kustomize (the old way):**
```bash
# You'd have to manually edit files for each environment 😞
# Edit k8s/deployments/api-gateway.yaml for local
# Edit k8s/deployments/api-gateway.yaml for AWS
# Edit k8s/deployments/api-gateway.yaml for Azure
# Easy to make mistakes! 😱
```

**With Kustomize (the new way):**
```bash
# Base stays the same ✅
# Overlays handle differences ✅
kubectl apply -k k8s/overlays/local   # Local deployment
kubectl apply -k k8s/overlays/aws    # AWS deployment
kubectl apply -k k8s/overlays/azure  # Azure deployment
```

**Benefits:**
- ✅ **One base, multiple environments** - No duplication
- ✅ **No manual editing** - Overlays handle changes automatically
- ✅ **Clear separation** - Base vs environment-specific
- ✅ **Easy to maintain** - Change base once, affects all environments

### **Local Pipeline Stages**

#### **Stage 1: Test & Lint**
```yaml
- Run unit tests for each service
- Run ESLint for code quality
- Matrix strategy (test all services in parallel)
```

**Why this order?**
- Catch bugs early (before building images)
- Fast feedback loop
- Parallel execution for speed

#### **Stage 2: Security Scanning (DevSecOps)**
```yaml
- Secret Scanning (Gitleaks + GitHub Secret Scanning)
- Snyk Dependency Scanning
- Snyk Container Scanning
- Trivy Vulnerability Scanning
- NPM Audit
```

**Why multiple scanners?**
- **Gitleaks**: Finds secrets in code (API keys, passwords)
- **Snyk**: Best for dependency vulnerabilities (comprehensive)
- **Trivy**: Fast container scanning (complementary to Snyk)
- **NPM Audit**: Node.js specific (catches what others miss)

**DevSecOps Principle**: Security is not an afterthought - it's integrated into every stage.

#### **Stage 3: Code Quality**
```yaml
- SonarQube Analysis (if configured)
- CodeClimate Analysis (alternative)
- ESLint across all services
- Code complexity metrics
```

**Why code quality matters?**
- Maintainable code = fewer bugs in production
- Early detection of complexity issues
- Team consistency

#### **Stage 4: Build Docker Images**
```yaml
- Build optimized multi-stage images
- Save as artifacts (for local deployment)
- Container security scanning
- Image optimization validation
```

**Why save as artifacts?**
- GitHub Actions runs on cloud runners (can't access local MicroK8s directly)
- Artifacts can be downloaded and deployed locally
- OR use self-hosted runner for automatic deployment

#### **Stage 5: Local Deployment** (Optional - requires self-hosted runner)
```yaml
- Load images into Colima
- Push to MicroK8s registry
- Deploy using Kustomize
- Health checks
- Integration tests
```

**Why optional?**
- Requires self-hosted runner on your Mac
- Manual deployment via `./scripts/build-and-deploy.sh` works fine too
- Self-hosted runner = fully automated local CI/CD

---

## ☁️ **Cloud CI/CD Pipeline**

### **Why Separate Cloud Pipeline?**

- ✅ **Different secrets** - AWS keys, cloud-specific configs
- ✅ **Different deployment** - EKS/AKS vs MicroK8s
- ✅ **Different environment** - Production vs local development
- ✅ **Clear separation** - Local learning vs cloud production

### **Cloud Pipeline Stages**

#### **Stage 1-3: Same as Local**
- Test, Security, Code Quality (identical)

#### **Stage 4: Build & Push to Cloud Registry**
```yaml
- Build Docker images
- Push to GitHub Container Registry (ghcr.io)
- Tag with version/branch/sha
```

#### **Stage 5: Deploy to Cloud**
```yaml
- Configure AWS credentials
- Update kubeconfig for EKS
- Deploy using Kustomize
- Blue-Green deployment strategy
- Health checks
- Rollback on failure
```

---

## 🔐 **Required Secrets**

### **For Local Pipeline (`cicd-local.yml`)**

#### **Required:**
- ✅ `SNYK_TOKEN` - For security scanning (recommended)
- ✅ `GITHUB_TOKEN` - Auto-provided by GitHub ✅

#### **Optional (for enhanced features):**
- ⚙️ `SONAR_TOKEN` - For SonarQube code quality analysis
- ⚙️ `SONAR_ORGANIZATION` - Your SonarCloud organization
- ⚙️ `CODECLIMATE_TEST_REPORTER_ID` - For CodeClimate analysis

**Minimum Setup**: Just `SNYK_TOKEN` (everything else works without it)

---

### **For Cloud Pipeline (`ci-cd.yml`)**

#### **Required:**
- ✅ `SNYK_TOKEN` - Security scanning
- ✅ `AWS_ACCESS_KEY_ID` - AWS deployment
- ✅ `AWS_SECRET_ACCESS_KEY` - AWS deployment
- ✅ `GITHUB_TOKEN` - Auto-provided ✅

#### **Optional:**
- ⚙️ `SLACK_WEBHOOK_URL` - Deployment notifications

---

## 🤖 **Self-Hosted Runner Setup**

### **Why Self-Hosted Runner?**

**Problem**: GitHub Actions runs on cloud runners, which can't access your local MicroK8s.

**Solution**: Run GitHub Actions runner on your Mac → Can access local MicroK8s directly!

### **Benefits:**

- ✅ **Automatic deployment** - No manual steps needed
- ✅ **Full CI/CD** - Test → Build → Deploy automatically
- ✅ **Local access** - Can use Colima, MicroK8s, kubectl directly
- ✅ **Faster** - No downloading artifacts needed

### **Setup Instructions**

#### **Step 1: Install GitHub Actions Runner**

```bash
# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download runner (macOS x64)
curl -o actions-runner-osx-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-osx-x64-2.311.0.tar.gz

# Configure runner (you'll get URL and token from GitHub)
./config.sh --url https://github.com/DevOps-Projects-by-Zee/payflow --token <YOUR_TOKEN>
```

**Get token from**: GitHub repo → Settings → Actions → Runners → New self-hosted runner

#### **Step 2: Configure Runner Labels**

When configuring, use these labels:
- `self-hosted`
- `macos`
- `local`

#### **Step 3: Install Runner Service**

```bash
# Install as service (starts automatically on boot)
sudo ./svc.sh install

# Start service
sudo ./svc.sh start

# Check status
./svc.sh status
```

#### **Step 4: Verify Setup**

```bash
# Check runner is online
# Go to: GitHub repo → Settings → Actions → Runners
# Should see your runner as "Online" with green dot
```

#### **Step 5: Test Deployment**

```bash
# Push a commit to trigger workflow
git commit --allow-empty -m "Test self-hosted runner"
git push

# Watch workflow in Actions tab
# Should see "Deploy to Local MicroK8s" job running
```

### **Troubleshooting**

#### **Issue: Runner not picking up jobs**
```bash
# Check runner status
cd ~/actions-runner
./svc.sh status

# Restart runner
sudo ./svc.sh restart

# Check logs
cat ~/actions-runner/_diag/Runner_*.log | tail -50
```

#### **Issue: Can't access MicroK8s**
```bash
# Verify kubectl access
export KUBECONFIG=~/.kube/microk8s-config
kubectl get nodes

# Verify Multipass access
multipass list

# Check runner has access to these paths
ls -la ~/.kube/microk8s-config
```

#### **Issue: Docker/Colima not accessible**
```bash
# Verify Colima is running
colima status

# Check Docker context
docker context ls
docker context use colima

# Test Docker access
docker ps
```

---

## 🔑 **How to Add Secrets to GitHub**

1. Go to: `https://github.com/DevOps-Projects-by-Zee/payflow`
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter name and value
5. Click **Add secret**

### **Secret Setup Guide**

#### **SNYK_TOKEN**
1. Sign up: [https://snyk.io](https://snyk.io)
2. Go to: Settings → API Token
3. Generate token
4. Copy and paste to GitHub Secrets

#### **SONAR_TOKEN** (Optional)
1. Sign up: [https://sonarcloud.io](https://sonarcloud.io)
2. Go to: My Account → Security
3. Generate token
4. Copy to GitHub Secrets

#### **SONAR_ORGANIZATION** (Optional)
1. In SonarCloud, note your organization name
2. Add as `SONAR_ORGANIZATION` secret

#### **CODECLIMATE_TEST_REPORTER_ID** (Optional)
1. Sign up: [https://codeclimate.com](https://codeclimate.com)
2. Go to: Settings → Test Reporter
3. Copy Test Reporter ID
4. Add to GitHub Secrets

---

## 📊 **Pipeline Comparison**

| Feature | Local Pipeline | Cloud Pipeline |
|---------|---------------|----------------|
| **Runner** | Self-hosted (Mac) or Cloud | Cloud (GitHub-hosted) |
| **Deployment Target** | MicroK8s (local) | AWS EKS / Azure AKS |
| **Image Registry** | MicroK8s registry | GitHub Container Registry |
| **Secrets Needed** | `SNYK_TOKEN` (minimal) | `SNYK_TOKEN`, `AWS_*` |
| **Deployment** | Kustomize → MicroK8s | Kustomize → EKS/AKS |
| **Use Case** | Learning, local dev | Production, cloud |

---

## 🎯 **Quick Start**

### **For Local Development (Recommended Start)**
```bash
# 1. Add SNYK_TOKEN to GitHub Secrets (optional but recommended)

# 2. Run pipeline manually or on push
# GitHub Actions will test, scan, and build

# 3. Deploy locally
./scripts/build-and-deploy.sh

# OR setup self-hosted runner for automatic deployment
```

### **For Cloud Deployment**
```bash
# 1. Add required secrets:
# - SNYK_TOKEN
# - AWS_ACCESS_KEY_ID
# - AWS_SECRET_ACCESS_KEY

# 2. Push to main branch
# Cloud pipeline will deploy automatically
```

---

## 🔗 **Related Documentation**

- [MicroK8s Setup](microk8s-setup.md) - Local Kubernetes setup
- [ArgoCD Setup](argocd-setup.md) - GitOps automation
- [Troubleshooting](../docs/TROUBLESHOOTING.md) - Common issues
- [AWS Deployment](aws-deployment.md) - Cloud deployment guide

---

## ✅ **Summary**

**Local Pipeline:**
- Tests → Security → Quality → Build → (Optional: Auto-deploy)
- Minimal secrets needed: `SNYK_TOKEN` only
- Deploys to: Your local MicroK8s

**Cloud Pipeline:**
- Tests → Security → Quality → Build → Push → Deploy
- Requires: `SNYK_TOKEN`, AWS credentials
- Deploys to: AWS EKS / Azure AKS

**Both pipelines follow DevSecOps principles** - security is integrated, not bolted on.
