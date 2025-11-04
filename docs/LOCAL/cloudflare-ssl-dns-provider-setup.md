# Cloudflare SSL & DNS Provider Nameserver Setup

## 🔒 **Fix: "This hostname is not covered by a certificate"**

This error means Cloudflare SSL/TLS isn't properly configured. Here's how to fix it:

### **Step 1: Configure SSL/TLS Mode in Cloudflare**

1. **Go to Cloudflare Dashboard**:
   - https://dash.cloudflare.com/
   - Select your `gameapp.games` domain
   - Click **SSL/TLS** → **Overview**

2. **Set SSL/TLS Mode**:
   - Change from "Off" or "Flexible" to **"Full"** or **"Full (strict)"**
   - **Recommended**: **"Full"** (works with self-signed certs)
   - **Best**: **"Full (strict)"** (requires valid SSL cert - use if you have one)

3. **Why this matters**:
   - Cloudflare needs to know how to handle SSL between edge and origin
   - Tunnel uses HTTP internally, but Cloudflare provides HTTPS to users
   - "Full" mode: Cloudflare encrypts user traffic → decrypts → sends HTTP to tunnel

### **Step 2: Verify SSL Settings**

1. Go to **SSL/TLS** → **Edge Certificates**
2. Ensure **"Always Use HTTPS"** is enabled (ON)
3. Check **"Automatic HTTPS Rewrites"** is enabled (ON)

### **Step 3: Restart Tunnel (if needed)**

After changing SSL mode, restart the tunnel:
```bash
export KUBECONFIG=~/.kube/microk8s-config
kubectl rollout restart deployment/cloudflare-tunnel -n payflow
```

---

## 🌐 **DNS Provider Nameserver Configuration**

Your domain needs to use Cloudflare's nameservers for Cloudflare Tunnel to work. Follow the steps below for your specific DNS provider/registrar.

### **First: Find Your Cloudflare Nameservers**

1. **Get from Cloudflare Dashboard**:
   - Go to: https://dash.cloudflare.com/
   - Select your domain (`gameapp.games` or your domain)
   - Look at the bottom of the **DNS** page
   - You'll see **"Cloudflare Nameservers"** section
   - Copy both nameservers (they look like: `katja.ns.cloudflare.com` and `sullivan.ns.cloudflare.com`)

2. **Example Nameservers** (yours will be different):
   ```
   katja.ns.cloudflare.com
   sullivan.ns.cloudflare.com
   ```
   *Note: Each Cloudflare account has unique nameservers - use YOURS from the dashboard!*

### **Update Nameservers at Your DNS Provider**

Choose your provider below and follow the steps:

---

#### **Namecheap**

1. Login: https://www.namecheap.com/
2. Go to **Domain List** → Click **Manage** next to your domain
3. Find **"Nameservers"** section
4. Select **"Custom DNS"**
5. Enter your Cloudflare nameservers (from above)
6. Click **"Save"**

---

#### **GoDaddy**

1. Login: https://www.godaddy.com/
2. Go to **My Products** → **Domains**
3. Click your domain → **DNS** tab
4. Scroll to **"Nameservers"** section
5. Click **"Change"**
6. Select **"Custom"**
7. Enter your Cloudflare nameservers
8. Click **"Save"**

---

#### **Google Domains / Google Workspace**

1. Login: https://domains.google.com/
2. Click your domain
3. Go to **DNS** → **Name servers**
4. Click **"Use custom name servers"**
5. Enter your Cloudflare nameservers
6. Click **"Save"**

---

#### **AWS Route 53**

1. Login: https://console.aws.amazon.com/route53/
2. Go to **Registered domains**
3. Click your domain → **Add/Edit Name Servers**
4. Click **"Edit"**
5. Replace existing nameservers with your Cloudflare nameservers
6. Click **"Update"**

---

#### **Hover**

1. Login: https://www.hover.com/
2. Go to **Domains** → Click your domain
3. Go to **Nameservers** tab
4. Click **"Change Nameservers"**
5. Select **"Use Custom Nameservers"**
6. Enter your Cloudflare nameservers
7. Click **"Save"**

---

#### **Name.com**

1. Login: https://www.name.com/
2. Go to **My Domains** → Click your domain
3. Go to **Nameservers** tab
4. Click **"Use Custom Nameservers"**
5. Enter your Cloudflare nameservers
6. Click **"Update Nameservers"**

---

#### **Cloudflare (if domain registered elsewhere but DNS managed in Cloudflare)**

1. Login: https://dash.cloudflare.com/
2. Select your domain
3. Go to **DNS** → Look at bottom of page
4. Nameservers are already displayed - use these at your registrar
5. Copy the nameservers shown
6. Update them at your domain registrar (where you bought the domain)

---

#### **Other Providers (Generic Steps)**

For any DNS provider, look for these options:

1. **Find Domain Management**:
   - Usually under "Domains", "DNS", "Nameservers", or "DNS Settings"

2. **Change Nameserver Type**:
   - Switch from "Default" or "Provider Nameservers" to **"Custom Nameservers"**

3. **Enter Cloudflare Nameservers**:
   - Replace existing nameservers with your Cloudflare nameservers
   - Most providers require 2 nameservers
   - Cloudflare always provides exactly 2

4. **Save Changes**:
   - Click "Save", "Update", or "Apply"
   - Some providers require confirmation

5. **Common Locations**:
   - Settings → DNS → Nameservers
   - Domain → Manage → Nameservers
   - DNS Settings → Custom Nameservers

---

### **Wait for Propagation**

- **Typical**: 1-4 hours
- **Maximum**: 24-48 hours
- **Check Status**: Use `dig NS yourdomain.com` or online tools like https://www.whatsmydns.net/

### **Verify Nameservers Are Active**

Check if nameservers have propagated:
```bash
# Check current nameservers
dig NS gameapp.games +short

# Should show:
# katja.ns.cloudflare.com
# sullivan.ns.cloudflare.com
```

**Online Checker**: https://www.whatsmydns.net/#NS/gameapp.games

---

## ✅ **Complete Setup Checklist**

- [ ] SSL/TLS mode set to "Full" in Cloudflare
- [ ] "Always Use HTTPS" enabled in Cloudflare
- [ ] Cloudflare nameservers retrieved from dashboard
- [ ] Nameservers updated at your DNS provider/registrar
- [ ] Nameserver propagation verified (can take 24-48h)
- [ ] Tunnel restarted (if SSL mode was changed)
- [ ] Test SSL: `curl -I https://yourdomain.com`

---

## 🔍 **Troubleshooting**

### **Issue: Certificate error persists**

**Solutions**:
1. Clear browser cache and try again
2. Wait 5-10 minutes after changing SSL mode
3. Verify SSL mode is "Full" not "Flexible"
4. Check Edge Certificates are active in Cloudflare dashboard

### **Issue: Nameservers not updating**

**Solutions**:
1. Verify nameservers are saved at your DNS provider
2. Check domain isn't locked or has transfer restrictions
3. Ensure you're using YOUR Cloudflare nameservers (not examples from docs)
4. Wait up to 48 hours for full propagation
5. Contact your DNS provider support if stuck
6. Verify domain isn't in "clientHold" or "serverHold" status

### **Issue: DNS not resolving**

**Check**:
```bash
# Check if nameservers are active (replace with your domain)
dig NS yourdomain.com

# Check if DNS records exist
dig yourdomain.com
dig app.yourdomain.com

# Check specific subdomain
dig grafana.yourdomain.com
```

---

## 📝 **Important Notes**

- **SSL Certificate**: Cloudflare provides free SSL certificates automatically
- **Nameserver Change**: This makes Cloudflare the authoritative DNS for your domain
- **DNS Records**: After updating nameservers, all DNS management happens in Cloudflare dashboard (not at your registrar)
- **Propagation Time**: Usually 1-4 hours, can take up to 48 hours maximum
- **Your Nameservers**: Each Cloudflare account has unique nameservers - always use YOURS from the dashboard, not examples
- **Domain Registration vs DNS**: You can keep your domain registered at your provider while using Cloudflare for DNS

---

**After completing these steps, your domain will have:**
- ✅ Free SSL/TLS certificates from Cloudflare
- ✅ DDoS protection
- ✅ CDN benefits
- ✅ Full tunnel functionality

