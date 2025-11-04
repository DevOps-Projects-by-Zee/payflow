# ArgoCD GitOps Setup Guide

## 🎯 **Why ArgoCD?**

ArgoCD brings **GitOps** to your Kubernetes deployments:
- ✅ **Automated sync** - Changes in Git automatically deploy to Kubernetes
- ✅ **Version control** - All infrastructure changes are tracked in Git
- ✅ **Rollback safety** - Easy to rollback to any previous version
- ✅ **Multi-environment** - Manage dev, staging, prod from one place
- ✅ **Production standard** - Used by enterprises worldwide

**Perfect for**: Learning GitOps, production deployment patterns, automated infrastructure management.

---

## 📋 **Prerequisites**

- ✅ MicroK8s running with PayFlow deployed (see [microk8s-setup.md](microk8s-setup.md))
- ✅ Git repository with your code (GitHub/GitLab)
- ✅ kubectl configured and working
- ✅ Basic understanding of Kubernetes

---

## 🚀 **Step-by-Step Setup**

### **Step 1: Install ArgoCD**

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/microk8s-config

# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD (official manifests)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD pods to be ready (takes 2-3 minutes)
kubectl wait --for=condition=ready pod -n argocd --all --timeout=300s

# Check ArgoCD status
kubectl get pods -n argocd
```

**✅ Success**: All ArgoCD pods should be `Running`

---

### **Step 2: Configure ArgoCD for Ingress**

```bash
# Configure ArgoCD to work behind ingress (insecure mode)
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true","url":"https://argocd.payflow.local"}}'

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Restart ArgoCD server to apply changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=120s
```

**Why**: ArgoCD runs behind our ingress, so it receives HTTP traffic internally.

---

### **Step 3: Set Up TLS Certificate**

```bash
# Apply certificate issuer (self-signed for local dev)
kubectl apply -f k8s/argocd/argocd-certificate-issuer.yaml

# Wait for certificate to be ready
kubectl wait --for=condition=ready certificate argocd-tls -n argocd --timeout=120s

# Verify certificate
kubectl get certificate -n argocd
kubectl get secret argocd-tls -n argocd
```

**✅ Success**: Certificate should show `READY True`

---

### **Step 4: Configure Ingress**

```bash
# Apply ArgoCD ingress
kubectl apply -f k8s/ingress/argocd-ingress.yaml

# Get the LoadBalancer IP
export ARGOCD_IP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Add to /etc/hosts
echo "$ARGOCD_IP argocd.payflow.local" | sudo tee -a /etc/hosts

# Verify ingress
kubectl get ingress -n argocd
```

**✅ Success**: Ingress should show the correct host

---

### **Step 5: Get ArgoCD Admin Password**

```bash
# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
echo ""
echo "Login at: https://argocd.payflow.local"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

**✅ Save this password** - You'll need it to log in!

---

### **Step 6: Access ArgoCD UI**

1. Open browser: `https://argocd.payflow.local`
2. Accept self-signed certificate warning
3. Login with:
   - Username: `admin`
   - Password: `[from Step 5]`

**✅ Success**: You should see the ArgoCD dashboard!

---

### **Step 7: Create PayFlow Application in ArgoCD**

```bash
# Apply the PayFlow application configuration
kubectl apply -f k8s/argocd/payflow-application.yaml

# Verify application created
kubectl get application -n argocd
```

**What this does**: Tells ArgoCD to watch your Git repo and sync changes to Kubernetes automatically.

---

### **Step 8: Configure Git Repository in ArgoCD**

**Important:** If your repository is **private**, you'll need to add authentication first. For **public** repositories, you can skip to Step 8b.

#### **Step 8a: For Private Repositories (Add Authentication)**

If your GitHub repository is private, ArgoCD needs credentials to access it:

1. **Create GitHub Personal Access Token:**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Name it: "ArgoCD Access"
   - Select scope: `repo` (full repository access)
   - Click "Generate token"
   - **Copy the token** (you'll only see it once!)

2. **Add Repository in ArgoCD UI:**
   - In ArgoCD UI, go to **Settings** → **Repositories**
   - Click **Connect Repo**
   - Fill in:
     - **Type**: Git
     - **Project**: default
     - **Repository URL**: `https://github.com/DevOps-Projects-by-Zee/payflow.git`
     - **Branch**: `main`
     - **Username**: Your GitHub username (or organization name)
     - **Password**: Paste your GitHub token here
   - Click **Connect**

3. **Verify Connection:**
   - The repository should show as "Connected" (green checkmark)
   - If you see "Repository not found" error, see troubleshooting below

#### **Step 8b: For Public Repositories (No Authentication)**

1. In ArgoCD UI, go to **Settings** → **Repositories**
2. Click **Connect Repo**
3. Fill in:
   - **Type**: Git
   - **Project**: default
   - **Repository URL**: `https://github.com/DevOps-Projects-by-Zee/payflow.git`
   - **Branch**: `main`
   - **Leave username/password empty** (public repos don't need credentials)
4. Click **Connect**

**✅ Success**: Repository shows as "Connected" in Settings → Repositories

**Common Issue: "Repository not found" Error**

If you get this error even for a public repo:
- **Check**: Make sure the repository is actually public (not private)
  - Go to your repo on GitHub
  - Check the visibility badge (should say "Public")
  - If it says "Private", make it public: Settings → Danger Zone → Change visibility → Make public
- **Wait**: After making repo public, wait 1-2 minutes for GitHub to update
- **Retry**: Click "Connect" again in ArgoCD

**Why This Matters:**
ArgoCD needs to read your repository to see what YAML files to deploy. Public repos don't need credentials, but private repos need a GitHub token so ArgoCD can authenticate.

---

### **Step 9: Sync Your Application**

1. In ArgoCD UI, click on **payflow** application
2. Click **Sync** button
3. Select all resources
4. Click **Synchronize**

**✅ Success**: ArgoCD will deploy all PayFlow services from your Git repo!

---

## ⚠️ **Common Setup Issues & Fixes**

### **Issue 1: Repository Authentication Error**

**Problem:** ArgoCD shows "Repository not found" or "authentication required" error.

**Why It Happens:**
- Your repository is private, but you didn't provide credentials
- Repository URL is wrong
- Repository doesn't exist yet

**Fix:**
1. **Make repository public** (easiest for beginners):
   - GitHub → Your repo → Settings → Danger Zone
   - Click "Change visibility" → "Make public"
   - Wait 2 minutes, then reconnect in ArgoCD

2. **OR add GitHub token** (if you want to keep it private):
   - See Step 8a above for detailed instructions
   - Generate token at: https://github.com/settings/tokens
   - Add token in ArgoCD Settings → Repositories

**Real Example:** When we first set up PayFlow, we got this error because the repo was private. We made it public, and it worked immediately!

---

### **Issue 2: Kustomize Build Errors**

**Problem:** ArgoCD shows errors like "namespace transformation produces ID conflict" or "duplicate ConfigMap".

**Why It Happens:**
- Multiple namespaces (payflow, monitoring, argocd) conflicting
- Duplicate resource names in same namespace
- Default namespace set incorrectly in kustomization.yaml

**Fix:**
1. **Remove default namespace** from `k8s/kustomization.yaml`:
   ```yaml
   # Remove this line:
   # namespace: payflow
   
   # Let each resource specify its own namespace
   ```

2. **Remove namespace override** from ArgoCD application:
   ```yaml
   # In k8s/argocd/payflow-application.yaml
   # Remove:
   #   kustomize:
   #     namespace: payflow
   ```

3. **Check for duplicate resources:**
   - Make sure you don't have two ConfigMaps with same name
   - Check kustomization.yaml - each file should only appear once

**Real Example:** We had a duplicate `grafana-dashboards` ConfigMap from two different files. We removed one from kustomization.yaml and it fixed the issue!

---

### **Issue 3: "Unable to load data" in ArgoCD UI**

**Problem:** ArgoCD UI shows "Unable to load data: Unsuccessful HTTP response".

**Why It Happens:**
- A sync operation is failing (broken secret, invalid resource)
- UI can't load data because sync is stuck
- ArgoCD server cache issue

**Fix:**
1. **Find the error:**
   ```bash
   kubectl describe application payflow -n argocd | grep -i error
   ```

2. **Fix the broken resource:**
   - Common issue: Secret with empty/invalid base64 value
   - Delete the broken secret: `kubectl delete secret <name> -n <namespace>`
   - Or fix the secret value

3. **Restart ArgoCD server:**
   ```bash
   kubectl rollout restart deployment argocd-server -n argocd
   ```

4. **Refresh browser** - UI should work now!

**Real Example:** We had `cloudflare-tunnel-secret` with empty value. Deleted it, and UI immediately started working!

---

## 🔄 **GitOps Workflow**

### **How It Works**

```
1. You make changes to k8s/ YAML files
2. Commit and push to Git
3. ArgoCD detects changes
4. ArgoCD automatically syncs to Kubernetes
5. Your changes are live!
```

### **Example Workflow**

```bash
# 1. Make a change (e.g., scale API Gateway)
# Edit: k8s/deployments/api-gateway.yaml
# Change replicas from 2 to 3

# 2. Commit and push
git add k8s/deployments/api-gateway.yaml
git commit -m "Scale API Gateway to 3 replicas"
git push origin main

# 3. ArgoCD automatically detects and syncs
# Check ArgoCD UI - you'll see the sync happening!

# 4. Verify in Kubernetes
kubectl get pods -n payflow -l app=api-gateway
# Should see 3 replicas now
```

---

## 🔧 **Common Operations**

### **Manual Sync**

In ArgoCD UI:
1. Click on application
2. Click **Sync**
3. Select resources to sync
4. Click **Synchronize**

### **Rollback to Previous Version**

In ArgoCD UI:
1. Click on application
2. Click **History**
3. Select version to rollback to
4. Click **Rollback**

### **Check Application Status**

```bash
# Get application status
kubectl get application payflow -n argocd

# Get detailed status
kubectl describe application payflow -n argocd
```

### **Update Application Configuration**

```bash
# Edit application config
kubectl edit application payflow -n argocd

# Or apply updated YAML
kubectl apply -f k8s/argocd/payflow-application.yaml
```

---

## 🐛 **Troubleshooting**

### **Issue: ArgoCD UI returns 404**

```bash
# Check if server is running
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check ingress configuration
kubectl describe ingress argocd-ingress -n argocd

# Verify ConfigMap settings
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 5 "server.insecure"
```

### **Issue: Application won't sync**

```bash
# Check application status
kubectl describe application payflow -n argocd

# Common causes:
# - Git repository not accessible
# - Wrong branch name
# - Path doesn't exist in repo
# - Kustomize errors
```

### **Issue: Certificate errors**

```bash
# Check certificate status
kubectl get certificate -n argocd

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=50
```

---

## 📊 **What You've Learned**

By completing ArgoCD setup, you've:
- ✅ Installed and configured ArgoCD
- ✅ Set up GitOps workflow
- ✅ Configured automated deployments
- ✅ Learned production GitOps patterns
- ✅ Set up TLS/HTTPS for ArgoCD

**This is production-grade infrastructure automation!** 🎉

---

## 🔗 **Related Documentation**

- [MicroK8s Setup](microk8s-setup.md) - Previous: Kubernetes setup
- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md) - Common issues
- [Cloudflare Tunnel](../README.md#cloudflare-tunnel) - Next: Public access

---

## 🎯 **Next Steps**

1. ✅ **Cloudflare Tunnel** - Set up secure public access (see README)
2. ✅ **Multi-Environment** - Set up dev/staging/prod in ArgoCD
3. ✅ **Cloud Deployment** - Deploy to AWS/Azure (see [aws-deployment.md](aws-deployment.md))

