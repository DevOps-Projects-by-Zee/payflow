# Post-Nameserver Setup: Complete Cloudflare Configuration

After adding nameservers to your DNS provider, follow these steps to complete the setup:

---

## ⏱️ **Step 1: Wait for Nameserver Propagation**

Nameserver changes can take **1-48 hours** to propagate globally (usually **1-4 hours**).

### **Check Propagation Status**:

```bash
# Check current nameservers
dig NS gameapp.games +short

# Should show YOUR Cloudflare nameservers (e.g.):
# katja.ns.cloudflare.com
# sullivan.ns.cloudflare.com

# If still showing registrar nameservers, wait longer
```

**Online Checker**: https://www.whatsmydns.net/#NS/gameapp.games

**While waiting**, proceed with Step 2 (SSL/TLS configuration).

---

## 🔒 **Step 2: Configure SSL/TLS in Cloudflare**

**Critical**: This fixes the "hostname not covered by certificate" error.

### **2.1: Set SSL/TLS Mode**

1. Go to **Cloudflare Dashboard**: https://dash.cloudflare.com/
2. Select your domain (`gameapp.games`)
3. Click **SSL/TLS** → **Overview**
4. Change **SSL/TLS encryption mode** to:
   - **"Full"** ← **Recommended** (works with HTTP backend)
   - **"Full (strict)"** (requires valid SSL cert on backend)

**Why "Full"?**
- Tunnel sends HTTP to your services (no SSL needed internally)
- Cloudflare provides HTTPS to end users
- "Full" mode: HTTPS (user) → decrypt → HTTP (tunnel) → your service

**❌ Don't use:**
- "Flexible" - Less secure, not recommended
- "Off" - No encryption

### **2.2: Enable Edge Certificates**

1. Still in Cloudflare Dashboard
2. Go to **SSL/TLS** → **Edge Certificates**
3. Enable these settings:
   - ✅ **"Always Use HTTPS"** → ON
   - ✅ **"Automatic HTTPS Rewrites"** → ON
   - ✅ **"Minimum TLS Version"** → 1.2 (or higher)

### **2.3: Verify Certificate Status**

1. Go to **SSL/TLS** → **Overview**
2. Check **"Edge Certificates"** status
3. Should show **"Active Certificate"** (Cloudflare provides this automatically)

---

## ✅ **Step 3: Verify DNS Records in Cloudflare**

Ensure all your DNS records are configured correctly:

1. Go to **DNS** → **Records**
2. Verify these CNAME records exist and are **Proxied** (orange cloud ☁️):

| Name | Type | Target | Proxy Status |
|------|------|--------|--------------|
| `@` (or `gameapp.games`) | CNAME | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ☁️ Proxied |
| `app` | CNAME | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ☁️ Proxied |
| `grafana` | CNAME | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ☁️ Proxied |
| `prometheus` | CNAME | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ☁️ Proxied |
| `argocd` | CNAME | `91aeb32f-008f-4fc8-ad0e-255ea67737a9.cfargotunnel.com` | ☁️ Proxied |

**Important**: All records MUST be **Proxied** (orange cloud), not "DNS only" (grey cloud).

---

## 🔍 **Step 4: Verify Tunnel Status**

### **4.1: Check in Cloudflare Dashboard**

1. Go to **Zero Trust** → **Networks** → **Tunnels**
2. Find `gameapp-tunnel`
3. Status should show:
   - **"UP"** (green) ← Good!
   - **"DOWN"** (red) ← Check tunnel pod logs

### **4.2: Check Tunnel Pod in Kubernetes**

```bash
export KUBECONFIG=~/.kube/microk8s-config

# Check pod status
kubectl get pods -n payflow -l app=cloudflare-tunnel

# Should show: Running

# Check logs
kubectl logs -n payflow -l app=cloudflare-tunnel --tail=20

# Should show: "Registered tunnel connection" messages
```

---

## 🧪 **Step 5: Test Public Access**

**After nameserver propagation** (usually 1-4 hours):

### **5.1: Test DNS Resolution**

```bash
# Check if domain resolves
dig gameapp.games

# Check specific subdomain
dig app.gameapp.games
dig grafana.gameapp.games
```

### **5.2: Test HTTPS Access**

```bash
# Test main site
curl -I https://gameapp.games

# Test API
curl -I https://app.gameapp.games/api/health

# Test Grafana (should redirect to login)
curl -I https://grafana.gameapp.games

# Test Prometheus
curl -I https://prometheus.gameapp.games

# Test ArgoCD
curl -I https://argocd.gameapp.games
```

**Expected Results**:
- ✅ HTTP 200 (OK)
- ✅ HTTP 301/302 (Redirect - OK)
- ✅ HTTP 401/403 (Authentication required - OK for Grafana/ArgoCD)
- ❌ HTTP 000 or connection refused (nameservers not propagated yet)

### **5.3: Test in Browser**

Open these URLs in your browser:
- ✅ https://gameapp.games → Should show PayFlow frontend
- ✅ https://app.gameapp.games/api/health → Should return JSON
- ✅ https://grafana.gameapp.games → Should show Grafana login
- ✅ https://prometheus.gameapp.games → Should show Prometheus UI
- ✅ https://argocd.gameapp.games → Should show ArgoCD login

---

## 🔧 **Troubleshooting**

### **Issue: Nameservers still not showing Cloudflare**

**Check**:
```bash
dig NS gameapp.games +short
```

**Solutions**:
1. Verify nameservers saved correctly at your DNS provider
2. Wait up to 48 hours (can take time)
3. Clear DNS cache: `sudo dscacheutil -flushcache` (macOS)
4. Try different DNS resolver: `dig NS gameapp.games @8.8.8.8 +short`

### **Issue: "This hostname is not covered by a certificate"**

**Solution**: Ensure SSL/TLS mode is set to **"Full"** in Cloudflare (Step 2.1)

### **Issue: Tunnel shows "DOWN" in Cloudflare**

**Check**:
```bash
export KUBECONFIG=~/.kube/microk8s-config
kubectl get pods -n payflow -l app=cloudflare-tunnel
kubectl logs -n payflow -l app=cloudflare-tunnel --tail=50
```

**Common causes**:
- Invalid tunnel token → Check secret
- Network connectivity → Check pod can reach Cloudflare
- Wrong tunnel ID → Verify ConfigMap

### **Issue: DNS resolves but HTTPS doesn't work**

**Solutions**:
1. Verify SSL/TLS mode is "Full" (not "Flexible")
2. Wait 5-10 minutes after changing SSL settings
3. Clear browser cache
4. Check "Always Use HTTPS" is enabled

### **Issue: 404 errors on subdomains**

**Check**:
1. Verify DNS records point to correct tunnel ID
2. Check tunnel ConfigMap has correct hostnames
3. Verify services are running in Kubernetes:
   ```bash
   kubectl get pods -n payflow
   kubectl get pods -n monitoring
   kubectl get pods -n argocd
   ```

---

## ✅ **Complete Setup Checklist**

- [ ] Nameservers propagated (showing Cloudflare nameservers)
- [ ] SSL/TLS mode set to "Full" in Cloudflare
- [ ] "Always Use HTTPS" enabled
- [ ] All DNS records created and Proxied (orange cloud)
- [ ] Tunnel shows "UP" in Cloudflare dashboard
- [ ] Tunnel pod running in Kubernetes
- [ ] HTTPS access working: `curl -I https://gameapp.games`
- [ ] All services accessible via browser

---

## 📝 **Summary**

**After nameserver propagation**:
1. ✅ Cloudflare becomes authoritative DNS
2. ✅ Free SSL certificates activate automatically
3. ✅ Tunnel routes traffic to your Kubernetes services
4. ✅ All services accessible via HTTPS

**Timeline**:
- Nameserver propagation: 1-4 hours (can take up to 48h)
- SSL certificate activation: Immediate after nameserver propagation
- Full functionality: 1-4 hours after nameserver update

---

**Next**: Once everything is working, you can:
- Set up Cloudflare Access (optional - for protected endpoints)
- Configure firewall rules
- Enable additional Cloudflare security features

