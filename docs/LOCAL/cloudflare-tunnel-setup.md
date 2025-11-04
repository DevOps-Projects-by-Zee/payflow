# Cloudflare Tunnel Setup Guide for PayFlow

## 🎯 **Why Cloudflare Tunnel?**

Cloudflare Tunnel creates a secure, outbound-only connection between your local Kubernetes cluster (MicroK8s) and Cloudflare's global network. This allows you to:
- ✅ **Expose services publicly** without a public IP address
- ✅ **No firewall port forwarding** required
- ✅ **Built-in DDoS protection** from Cloudflare
- ✅ **Free SSL/TLS certificates** automatically managed
- ✅ **Access from anywhere** via `gameapp.games`

**Perfect for**: Sharing your PayFlow project publicly, demonstrating production-ready infrastructure, and learning how modern applications are exposed.

---

## 🚀 **Prerequisites**

- Cloudflare account with `gameapp.games` domain
- Existing tunnel: `gameapp-tunnel` (ID: `91aeb32f-008f-4fc8-ad0e-255ea67737a9`)
- MicroK8s cluster running locally
- PayFlow application deployed and working locally

---

## 📋 **Step-by-Step Setup**

### **Step 1: Get Tunnel Token from Command Line (Recommended)**

**Using cloudflared CLI (fastest method)**:

```bash
# 1. Install cloudflared (if not already installed)
brew install cloudflared

# 2. Login to Cloudflare (opens browser for authentication)
cloudflared tunnel login

# 3. List your tunnels to verify
cloudflared tunnel list
# Should show: gameapp-tunnel (ID: 91aeb32f-008f-4fc8-ad0e-255ea67737a9)

# 4. Get tunnel token (this is what you need!)
cloudflared tunnel token 91aeb32f-008f-4fc8-ad0e-255ea67737a9

# Copy the entire token output (starts with eyJ...)
# It's a long string - copy it all!
```

**What the token looks like**:
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IjEyMzQ1Njc4OTBhYmNkZWYxMjM0NTY3ODkwYWJjZGVmIn0.eyJpc3MiOiJodHRwczovL2Nsb3VkZmxhcmUuY29tIiwiaWF0IjoxNjAwMDAwMDAwLCJleHAiOjE2MDAwMDAwMDAsImF1ZCI6Imh0dHBzOi8vYXBpLmNsb3VkZmxhcmUuY29tIiwiZW1haWwiOiJ5b3VyLWVtYWlsQGV4YW1wbGUuY29tIn0.very-long-token-string-here...
```

**Alternative: Get Token from Cloudflare Dashboard**:
1. Navigate to: https://one.dash.cloudflare.com/
2. Click **Zero Trust** → **Networks** → **Tunnels**
3. Click on `gameapp-tunnel`
4. Click **Configure** or **Install connector**
5. Copy the token shown

---

### **Step 2: Update Tunnel Secret in Kubernetes**

1. **Edit the secret file**:
   ```bash
   # Open the secret template
   nano k8s/secrets/cloudflare-tunnel-secret.yaml
   ```

2. **Replace the placeholder**:
   ```yaml
   stringData:
     tunnel_token: "YOUR_ACTUAL_TOKEN_HERE"  # Paste token from Step 1
   ```

3. **Save the file**

---

### **Step 3: Configure DNS in Cloudflare Dashboard**

Before deploying, set up DNS records in Cloudflare to route traffic to your tunnel.

**Target for all records**: `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com`

1. **Go to Cloudflare Dashboard**:
   - Navigate to: https://dash.cloudflare.com/
   - Select your `gameapp.games` domain
   - Click **DNS** → **Records**
   - Click **Add record**

2. **Create All DNS Records** (repeat for each):

   | Type | Name | Target | Proxy Status |
   |------|------|--------|--------------|
   | CNAME | `@` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied (orange cloud) |
   | CNAME | `www` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied |
   | CNAME | `api` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied |
   | CNAME | `grafana` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied |
   | CNAME | `prometheus` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied |
   | CNAME | `argocd` | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ✅ Proxied |

3. **For Each Record**:
   - **Type**: Select `CNAME`
   - **Name**: Enter the subdomain (e.g., `api`, `grafana`, etc.)
   - **Target**: `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com`
   - **Proxy status**: Click the orange cloud ☁️ to enable (must be Proxied!)
   - **TTL**: Auto
   - Click **Save**

**Important Notes**:
- ✅ **All records must be Proxied** (orange cloud icon) - this enables Cloudflare's protection and SSL
- ✅ **Use the same target** for all records - the tunnel ID routes to your tunnel
- ✅ **Root domain** (`@`) is for `gameapp.games`
- ✅ **Subdomains** (`api`, `grafana`, etc.) create `api.gameapp.games`, `grafana.gameapp.games`

**Final DNS Setup**:
After adding all records, you should see:
```
@           CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
www         CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
api         CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
grafana     CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
prometheus  CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
argocd      CNAME   91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com   ☁️ Proxied
```

**Why CNAME to `.cfargotunnel.com`?**
- Cloudflare Tunnel uses these special hostnames to route traffic to your tunnel
- The tunnel ID in the hostname ensures traffic goes to YOUR tunnel instance
- Cloudflare's edge network handles routing based on the DNS name

---

### **Step 4: Deploy Cloudflare Tunnel to Kubernetes**

1. **Apply the secret** (with your real token):
   ```bash
   export KUBECONFIG=~/.kube/microk8s-config
   kubectl apply -f k8s/secrets/cloudflare-tunnel-secret.yaml
   ```

2. **Verify secret created**:
   ```bash
   kubectl get secret cloudflare-tunnel-secret -n payflow
   ```

3. **Deploy Cloudflare Tunnel**:
   ```bash
   kubectl apply -f k8s/deployments/cloudflare-tunnel.yaml
   ```

4. **Wait for tunnel pod to start**:
   ```bash
   kubectl wait --for=condition=ready pod -l app=cloudflare-tunnel -n payflow --timeout=120s
   ```

5. **Check tunnel status**:
   ```bash
   kubectl get pods -n payflow | grep cloudflare
   kubectl logs -n payflow deployment/cloudflare-tunnel --tail=50
   ```

**✅ Success**: You should see logs showing tunnel connection established.

---

### **Step 5: Verify Public Access**

1. **Check tunnel status in Cloudflare**:
   - Go back to Cloudflare Zero Trust → Networks → Tunnels
   - `gameapp-tunnel` should now show **"UP"** (green)

2. **Test public access** (wait 5-15 minutes for DNS propagation):
   ```bash
   # Test main site
   curl -I https://gameapp.games
   curl -I https://www.gameapp.games
   
   # Test API
   curl -I https://api.gameapp.games/api/health
   
   # Test Grafana (should redirect to login)
   curl -I https://grafana.gameapp.games
   
   # Test Prometheus
   curl -I https://prometheus.gameapp.games
   
   # Test ArgoCD
   curl -I https://argocd.gameapp.games
   ```

3. **Access in browser** (all services):
   - ✅ https://gameapp.games → PayFlow Frontend
   - ✅ https://www.gameapp.games → PayFlow Frontend (alternative)
   - ✅ https://api.gameapp.games → API Gateway
   - ✅ https://grafana.gameapp.games → Grafana Dashboard
   - ✅ https://prometheus.gameapp.games → Prometheus Metrics
   - ✅ https://argocd.gameapp.games → ArgoCD UI

---

## 🔒 **SSL Certificate & DNS Provider Setup**

If you see "This hostname is not covered by a certificate" error:
- See **[docs/cloudflare-ssl-dns-provider-setup.md](cloudflare-ssl-dns-provider-setup.md)** for complete guide
- Fix SSL/TLS mode in Cloudflare (set to "Full")
- Update nameservers at your DNS provider/registrar

---

## 🛠️ **Troubleshooting**

### **Issue: Tunnel Status Still "DOWN"**

**Symptoms**:
- Tunnel shows as DOWN in Cloudflare dashboard
- Pod logs show connection errors

**Solutions**:
```bash
# Check pod logs
kubectl logs -n payflow deployment/cloudflare-tunnel --tail=100

# Common issues:
# 1. Invalid token - check secret:
kubectl get secret cloudflare-tunnel-secret -n payflow -o yaml

# 2. Wrong tunnel ID - check ConfigMap:
kubectl get configmap cloudflare-tunnel-config -n payflow -o yaml

# 3. Network issues - check pod connectivity:
kubectl exec -n payflow deployment/cloudflare-tunnel -- wget -O- https://www.cloudflare.com
```

### **Issue: DNS Not Resolving**

**Symptoms**:
- `curl https://gameapp.games` returns DNS error
- Browser shows "site can't be reached"

**Solutions**:
1. **Verify DNS records**:
   - Check Cloudflare dashboard → DNS → Records
   - Ensure CNAME records point to `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com`
   - Ensure proxy is enabled (orange cloud ☁️)

2. **Wait for DNS propagation**:
   ```bash
   # Check DNS resolution
   dig gameapp.games
   dig api.gameapp.games
   
   # Should resolve to Cloudflare IPs (not your local IP)
   ```

3. **Clear DNS cache**:
   ```bash
   # macOS
   sudo dscacheutil -flushcache
   sudo killall -HUP mDNSResponder
   ```

### **Issue: 404 Errors on Subdomains**

**Symptoms**:
- Main site works, but `api.gameapp.games` returns 404

**Solutions**:
1. **Check tunnel config**:
   ```bash
   kubectl get configmap cloudflare-tunnel-config -n payflow -o yaml
   ```
   - Verify hostnames match DNS records
   - Ensure services are accessible within cluster

2. **Test internal connectivity**:
   ```bash
   # From tunnel pod, test internal services
   kubectl exec -n payflow deployment/cloudflare-tunnel -- wget -O- http://api-gateway.payflow.svc.cluster.local:3000/api/health
   ```

3. **Verify DNS records match config**:
   - `api.gameapp.games` DNS → `api` hostname in config
   - `grafana.gameapp.games` DNS → `grafana` hostname in config

---

## 🔒 **Security Considerations**

1. **Keep Tunnel Token Secret**:
   - Never commit `k8s/secrets/cloudflare-tunnel-secret.yaml` to Git
   - Use `kubectl create secret` if managing manually

2. **Access Control** (Optional):
   - Cloudflare Zero Trust Access can add authentication
   - Useful for Grafana/ArgoCD (keep them private)

3. **Rate Limiting**:
   - Cloudflare automatically provides DDoS protection
   - Consider adding rate limiting rules in Cloudflare dashboard

---

## 📊 **Monitoring Tunnel Health**

```bash
# Check tunnel pod status
kubectl get pods -n payflow -l app=cloudflare-tunnel

# View real-time logs
kubectl logs -n payflow deployment/cloudflare-tunnel -f

# Check tunnel metrics (if available)
kubectl exec -n payflow deployment/cloudflare-tunnel -- cloudflared tunnel info 91aeb32f-008f-4fc8-ad0e-255ea67737a9
```

---

## 🔄 **Restarting Tunnel (If It Goes Down)**

**Note:** You don't need to reapply Kubernetes manifests. The deployment should auto-restart pods.

**If tunnel goes down:**
```bash
export KUBECONFIG=~/.kube/microk8s-config
kubectl rollout restart deployment/cloudflare-tunnel -n payflow
```

**If pods are stuck/crashed:**
```bash
export KUBECONFIG=~/.kube/microk8s-config
kubectl delete pod -n payflow -l app=cloudflare-tunnel
```

The deployment should auto-restart pods. Restart only if needed.

**Common issue:** Missing secret - if pods show "ContainerCreating" for too long, check:
```bash
kubectl get secret cloudflare-tunnel-secret -n payflow
# If missing, apply: kubectl apply -f k8s/secrets/cloudflare-tunnel-secret.yaml
```

---

## 🎯 **Next Steps**

After tunnel is working:
1. ✅ Test all endpoints (`gameapp.games`, `api.gameapp.games`, `grafana.gameapp.games`)
2. ✅ Set up Cloudflare Access (optional) for protected endpoints
3. ✅ Configure SSL/TLS settings in Cloudflare dashboard
4. ✅ Add monitoring/alerts for tunnel uptime

---

## 📚 **Resources**

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Tunnel Configuration Reference](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/config/)
- [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)

---

**✅ Setup Complete!** Your PayFlow application is now publicly accessible via `gameapp.games`!

