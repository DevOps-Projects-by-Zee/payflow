# Fix: ERR_SSL_VERSION_OR_CIPHER_MISMATCH

## 🔍 **Understanding the Error**

`ERR_SSL_VERSION_OR_CIPHER_MISMATCH` occurs when:
1. **TLS Version Mismatch (Most Common)**: Cloudflare minimum TLS is 1.0, but modern browsers don't support TLS 1.0 anymore. Browser and Cloudflare can't agree on a protocol version.
2. **Cipher Suite Mismatch**: Browser and server can't find a common encryption cipher (rare with Cloudflare).

**Most Likely Cause**: Cloudflare SSL/TLS → Edge Certificates → Minimum TLS Version is set to "TLS 1.0 (default)". Modern browsers (Chrome, Firefox, Safari, Edge) removed TLS 1.0 support, causing the mismatch.

**Note**: The `originCertPath` error in tunnel logs is **normal** when using token-based authentication (which we are). It's a warning, not the cause of the SSL error.

---

## ✅ **Solution: Fix Cloudflare SSL/TLS Settings**

The issue is in Cloudflare's SSL/TLS configuration, not the tunnel itself.

### **Step 1: Verify SSL/TLS Mode is "Full"**

1. Go to **Cloudflare Dashboard**: https://dash.cloudflare.com/
2. Select your domain (`gameapp.games`)
3. Navigate: **SSL/TLS** → **Overview**
4. Check **"SSL/TLS encryption mode"**
5. **Must be set to: "Full"** (not "Flexible" or "Off")

**Why "Full"?**
- Tunnel uses HTTP internally (no SSL needed)
- Cloudflare provides HTTPS to users
- "Full" mode: HTTPS (user) → decrypt → HTTP (tunnel) → your service

### **Step 2: Check Edge Certificates**

1. Still in Cloudflare Dashboard
2. Go to **SSL/TLS** → **Edge Certificates**
3. Verify:
   - ✅ **"Always Use HTTPS"** is **ON**
   - ✅ **"Automatic HTTPS Rewrites"** is **ON**
   - ✅ Certificate status shows **"Active Certificate"**

**If certificate shows "Pending"**:
- Wait 5-15 minutes for automatic provisioning
- Cloudflare creates certificates automatically after nameserver propagation

### **Step 3: Check Minimum TLS Version**

1. **SSL/TLS** → **Edge Certificates**
2. Scroll to **"Minimum TLS Version"**
3. Set to **"1.2"** or **"1.3"** (not lower)

### **Step 4: Clear Browser Cache**

After changing SSL settings:
- Clear browser cache
- Try incognito/private window
- Or wait 5-10 minutes for changes to propagate

---

## 🔧 **Alternative: If "Full" Mode Doesn't Work**

If "Full" mode still causes issues, try:

### **Option 1: Use "Full (strict)"**
- Requires valid SSL certificate on your backend
- **Only use if you have SSL certs in Kubernetes**

### **Option 2: Temporarily Use "Flexible" (Not Recommended)**
- Less secure
- Only for testing
- Change back to "Full" after verification

---

## 🧪 **Testing After Fix**

```bash
# Test HTTPS connection
curl -I https://gameapp.games

# Should return:
# HTTP/2 200
# OR
# HTTP/2 301/302 (redirects are OK)
```

**In Browser**:
- Open https://gameapp.games
- Should load without SSL errors
- If you see "Your connection is not private" → certificate still provisioning (wait)

---

## 🔍 **Verify Tunnel Configuration**

Your tunnel is using token-based auth (correct). Verify:

```bash
export KUBECONFIG=~/.kube/microk8s-config

# Check tunnel pod is running
kubectl get pods -n payflow -l app=cloudflare-tunnel

# Check logs (should show "Registered tunnel connection")
kubectl logs -n payflow -l app=cloudflare-tunnel --tail=10
```

**Expected logs**:
```
INF Registered tunnel connection connIndex=0
INF Tunnel connection established
```

**No errors about "originCertPath"** - that warning is harmless for token auth.

---

## 📝 **Common Causes**

1. **SSL/TLS mode is "Flexible"** → Change to "Full"
2. **Certificate still provisioning** → Wait 5-15 minutes
3. **Browser cache** → Clear cache or use incognito
4. **TLS version mismatch** → Set minimum TLS to 1.2+
5. **DNS not fully propagated** → Check nameservers

---

## ✅ **Quick Checklist**

- [ ] SSL/TLS mode = **"Full"** (not Flexible)
- [ ] "Always Use HTTPS" = **ON**
- [ ] Edge Certificate = **Active** (not Pending)
- [ ] Minimum TLS = **1.2** or higher
- [ ] Nameservers propagated (showing Cloudflare nameservers)
- [ ] Tunnel pod running (check Kubernetes)
- [ ] Tunnel logs show "Registered connection"
- [ ] Cleared browser cache
- [ ] Waited 5-10 minutes after SSL changes

---

## 🆘 **Still Not Working? (Advanced Troubleshooting)**

If SSL/TLS mode is already "Full" and still getting ERR_SSL_VERSION_OR_CIPHER_MISMATCH:

### **🔥 Most Common Causes (Check These First):**

#### **1. Certificate Still Provisioning (Most Likely)**

Even with "Full" mode, Cloudflare needs time to provision certificates.

1. Go to **SSL/TLS** → **Edge Certificates**
2. Look for **"Certificate Status"** or **"Edge Certificates"** section
3. Check status:
   - ⏳ **"Pending"** or **"Provisioning"** = **Wait 15-30 more minutes**
   - ✅ **"Active Certificate"** = Certificate is ready, check other items
   - ❌ **"Error"** or **"Failed"** = Contact Cloudflare support

**Action**: If "Pending", wait 15-30 minutes and check again. Cloudflare automatically provisions certificates after nameserver propagation, but it can take time.

#### **2. DNS Record Not Proxied (Very Common)**

**Critical**: The CNAME record must be **Proxied** (orange cloud), not **DNS only** (grey cloud).

1. Go to **DNS** → **Records**
2. Find the record for `gameapp.games` (or `@`)
3. Check the cloud icon:
   - ✅ **Orange cloud ☁️** = Proxied (correct)
   - ❌ **Grey cloud** = DNS only (wrong - fix this!)

**If grey cloud**:
1. Click the grey cloud icon
2. It should turn orange ☁️
3. Wait 2-5 minutes for change to propagate
4. Test again

**Why this matters**: Only Proxied records get SSL certificates from Cloudflare!

#### **3. Minimum TLS Version Too High**

1. Go to **SSL/TLS** → **Edge Certificates**
2. Scroll to **"Minimum TLS Version"**
3. Current setting might be too restrictive
4. **Temporarily** set to **"1.0"** (for testing)
5. Test: `curl -I https://gameapp.games`
6. If works, set back to **"1.2"** or **"1.3"**

#### **4. Test with "Flexible" Mode (Diagnostic)**

This helps identify if it's a certificate/protocol issue:

1. Go to **SSL/TLS** → **Overview**
2. **Temporarily** change to **"Flexible"** (not recommended for production)
3. Wait 2-3 minutes
4. Test: `curl -I https://gameapp.games` or open in browser
5. **If it works**:
   - Certificate/protocol issue confirmed
   - Change back to **"Full"**
   - Wait 15-30 minutes for certificate to fully provision
   - Try again
6. **If still fails**:
   - Check DNS proxy status (step 2)
   - Check tunnel status (step 5)

### **5. Purge Cloudflare Cache**

Cached SSL configuration might be causing issues:

1. Go to **Caching** → **Configuration**
2. Click **"Purge Everything"**
3. Wait 30-60 seconds
4. Try accessing the site again

### **6. Verify Tunnel is UP**

1. Go to **Zero Trust** → **Networks** → **Tunnels**
2. Find `gameapp-tunnel`
3. Status must be **"UP"** (green)
4. If **"DOWN"** (red):
   ```bash
   export KUBECONFIG=~/.kube/microk8s-config
   kubectl logs -n payflow -l app=cloudflare-tunnel --tail=50
   ```
   Look for connection errors and share them

### **7. Check Domain Status**

1. Go to domain **Overview** page
2. Check for any warnings or error messages
3. Verify domain shows as **"Active"** (not paused or pending)

### **8. Browser-Specific Issues**

Test from different clients:
```bash
# Test with curl
curl -v https://gameapp.games 2>&1 | head -20

# Test HTTP (should redirect to HTTPS)
curl -I http://gameapp.games

# Test in incognito browser window
# Test from mobile network
```

### **9. Force Certificate Reissue (Last Resort)**

1. Go to **SSL/TLS** → **Edge Certificates**
2. Scroll to bottom
3. Look for **"Re-verify Certificate"** or **"Renew Certificate"** option
4. Click if available
5. Wait 10-15 minutes

---

## 📋 **Action Plan (In Order)**

1. ✅ **Check certificate status** → If "Pending", wait 15-30 minutes
2. ✅ **Verify DNS record is Proxied** → Must be orange cloud ☁️
3. ✅ **Test with "Flexible" mode** → Helps identify issue
4. ✅ **Check minimum TLS version** → Try 1.0 temporarily
5. ✅ **Purge cache** → Clear Cloudflare cache
6. ✅ **Verify tunnel UP** → Check Zero Trust dashboard

---

**90% of cases**: Certificate still provisioning OR DNS record not Proxied (grey cloud).

