# Monitoring & Observability Guide

## 🎯 **What is Monitoring?**

Monitoring is like having a **health checkup for your application**. Just like a doctor monitors your vital signs (heart rate, blood pressure), we monitor our application's vital signs (CPU, memory, response time, errors).

### **Why Monitoring Matters for PayFlow**

As a **fintech application**, PayFlow handles money transactions. If something goes wrong:
- 💰 **Money could be lost**
- 👥 **Users could be locked out**
- 🏦 **Regulatory compliance issues**
- 📉 **Business reputation damage**

**Monitoring helps us catch problems BEFORE they affect users!**

---

## 🏗️ **PayFlow Monitoring Stack**

### **The Three Pillars of Observability**

1. **📊 Metrics** - Numbers that tell us how the system is performing
2. **📝 Logs** - Text records of what happened
3. **🔍 Traces** - Following a request through multiple services

### **Our Monitoring Tools**

| Tool | Purpose | URL | What It Shows |
|------|---------|-----|---------------|
| **Prometheus** | Metrics Collection | http://localhost:9090 | Raw metrics data |
| **Grafana** | Dashboards | http://localhost:3006 | Beautiful visualizations |
| **AlertManager** | Alerts | http://localhost:9093 | Notifications when things go wrong |
| **Loki** | Log Aggregation | http://localhost:3100 | Centralized logs |

---

## 📊 **Understanding Metrics**

### **What Are Metrics?**

Metrics are **numbers that change over time**. Think of them like a speedometer in your car:

- **Speed**: How fast are we processing requests?
- **Fuel**: How much memory are we using?
- **Temperature**: How hot is our CPU getting?

### **Key PayFlow Metrics**

#### **1. Request Rate**
```
What it measures: How many requests per second
Why it matters: High rate = busy system, Low rate = maybe broken
Normal range: 10-100 requests/second
```

#### **2. Response Time**
```
What it measures: How long requests take to complete
Why it matters: Slow responses = unhappy users
Normal range: 50-200ms for API calls
```

#### **3. Error Rate**
```
What it measures: Percentage of failed requests
Why it matters: High error rate = something is broken
Normal range: Less than 1% errors
```

#### **4. Memory Usage**
```
What it measures: How much RAM each service uses
Why it matters: High memory = potential crash
Normal range: 50-200MB per service
```

#### **5. CPU Usage**
```
What it measures: How hard the CPU is working
Why it matters: High CPU = slow responses
Normal range: 10-50% under normal load
```

---

## 🎛️ **Using Grafana Dashboard**

### **Accessing the Dashboard**

1. **Open Grafana**: http://localhost:3006
2. **Login**: `admin` / `admin`
3. **Navigate**: Go to "Dashboards" → "PayFlow Production Dashboard"

### **Understanding the Dashboard**

#### **Top Row - Performance Overview**
- **Request Rate by Service**: How busy each service is
- **Service Success Rate**: Are services healthy? (1 = healthy, 0 = down)

#### **Second Row - Response Times**
- **Response Time Percentiles**: P50 (average) and P95 (slowest 5%)
- **Error Rate by Service**: How many requests are failing

#### **Third Row - Resource Usage**
- **Memory Usage by Service**: RAM consumption
- **CPU Usage by Service**: CPU consumption

#### **Fourth Row - System Health**
- **Service Health Status**: Overall system health
- **Transaction Metrics**: Business metrics (successful/failed transactions)

#### **Bottom Row - Application Metrics**
- **Node.js Metrics**: JavaScript-specific metrics
- **Notification Metrics**: Email/SMS sending rates

### **Reading the Graphs**

#### **Line Graphs**
- **X-axis**: Time (last 5 minutes)
- **Y-axis**: The metric value
- **Lines**: Different services (different colors)

#### **What to Look For**
- **Spikes**: Sudden increases (might indicate problems)
- **Trends**: Gradual changes (might indicate issues building up)
- **Flat Lines**: No activity (might indicate service is down)

---

## 🔍 **Troubleshooting with Monitoring**

### **Step 1: Identify the Problem**

#### **Service Down (Red Alert)**
```
Symptom: Service Success Rate shows 0
Check: Service Health Status panel
Action: Check service logs
```

#### **High Response Time**
```
Symptom: Response Time Percentiles > 500ms
Check: CPU Usage panel
Action: Scale up service or optimize code
```

#### **High Error Rate**
```
Symptom: Error Rate > 5%
Check: Service logs
Action: Check database connections, external APIs
```

#### **High Memory Usage**
```
Symptom: Memory Usage > 200MB
Check: Memory Usage panel
Action: Restart service or check for memory leaks
```

### **Step 2: Drill Down Investigation**

#### **Check Service Logs**
```bash
# Docker Compose
docker-compose logs <service-name>

# Kubernetes
kubectl logs <pod-name> -n payflow
```

#### **Check Specific Metrics**
```bash
# Check if service is responding
curl http://localhost:3000/health

# Check Prometheus directly
curl http://localhost:9090/api/v1/query?query=up
```

#### **Check Database Connections**
```bash
# PostgreSQL
docker-compose exec postgres psql -U payflow -d payflow -c "SELECT 1;"

# Redis
docker-compose exec redis redis-cli ping
```

### **Step 3: Common Issues & Solutions**

#### **Issue: "No Data" in Grafana**
**Causes:**
- Service is down
- Prometheus can't reach service
- Metric name changed

**Solutions:**
```bash
# Check if service is running
docker-compose ps

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check service metrics endpoint
curl http://localhost:3000/metrics
```

#### **Issue: High CPU Usage**
**Causes:**
- Too many requests
- Inefficient code
- Resource limits too low

**Solutions:**
```bash
# Scale up service
docker-compose up -d --scale api-gateway=3

# Check resource limits
docker stats
```

#### **Issue: High Memory Usage**
**Causes:**
- Memory leak
- Too much data in memory
- Resource limits too low

**Solutions:**
```bash
# Restart service
docker-compose restart <service-name>

# Check for memory leaks
docker-compose logs <service-name> | grep -i memory
```

---

## 📝 **Understanding Logs**

### **What Are Logs?**

Logs are **text records** of what happened in your application. Think of them like a diary:

```
2024-01-15 10:30:15 INFO: User john@example.com logged in
2024-01-15 10:30:16 INFO: Transaction started: $100 from john to jane
2024-01-15 10:30:17 ERROR: Database connection failed
```

### **Log Levels**

| Level | Meaning | When to Use |
|-------|---------|-------------|
| **ERROR** | Something went wrong | Database errors, API failures |
| **WARN** | Something unusual happened | Slow responses, retries |
| **INFO** | Normal operation | User login, transaction completed |
| **DEBUG** | Detailed information | Variable values, function calls |

### **Reading PayFlow Logs**

#### **API Gateway Logs**
```bash
docker-compose logs api-gateway
```
**Look for:**
- Request/response times
- Authentication failures
- Rate limiting hits

#### **Transaction Service Logs**
```bash
docker-compose logs transaction-service
```
**Look for:**
- Transaction processing
- Database errors
- Queue processing

#### **Auth Service Logs**
```bash
docker-compose logs auth-service
```
**Look for:**
- Login attempts
- Token generation
- Password validation

---

## 🚨 **Understanding Alerts & Alert Rules**

### **What Are Alert Rules?**

Alert rules are **conditions** defined in Prometheus that continuously monitor your application metrics. Think of them like a security system that watches your house 24/7:

- **When everything is normal**: Rules check metrics but don't fire (Inactive state)
- **When something goes wrong**: Rules detect the problem and fire an alert (Firing state)
- **You get notified**: AlertManager sends you a notification

**Example:**
```yaml
# Alert Rule: Service Down
- alert: ServiceDown
  expr: up{job="api-gateway"} == 0  # Check if service is down
  for: 2m                           # Fire after 2 minutes
  labels:
    severity: critical              # This is urgent!
  annotations:
    summary: "API Gateway is down"   # What's wrong?
    description: "Service has been down for 2 minutes"  # Details
```

### **Why Are Alert Rules Needed?**

#### **1. Proactive Problem Detection** ⚡
**Without Alerts:**
- User notices the problem first
- By the time you know, users are already affected
- Downtime: 15-30+ minutes

**With Alerts:**
- You know within 2 minutes
- Fix it before users notice
- Downtime: 2-5 minutes

**Real Example:**
```
Scenario: Database connection pool exhausted

Without Alert Rules:
1. User tries transaction → Fails
2. More users try → All fail
3. User reports issue (15 min later)
4. Engineer investigates → Finds database issue
5. Time lost: 30+ minutes, multiple failed transactions

With Alert Rules:
1. Connection pool starts filling (90% used)
2. Alert fires: "DatabaseConnectionPoolExhausted" (2 min after issue)
3. Engineer notified immediately
4. Engineer checks database → Finds stuck connection
5. Issue resolved before users affected
6. Time saved: Issue caught in <5 minutes, zero user impact
```

#### **2. Business Continuity for Fintech** 💰
For PayFlow (a fintech app handling money):
- **Transaction failures** → Immediate alert (protects money)
- **Wallet balance anomalies** → Security alert (potential fraud)
- **Database issues** → Alert before all transactions fail
- **High error rate** → Alert before system crashes

**Impact:** Preventing even one transaction failure can save significant money and user trust.

#### **3. Performance Monitoring** 📈
- **Response time increasing** → Alert before users complain
- **CPU usage high** → Alert before services become unresponsive
- **Memory leak** → Alert before OOM (Out of Memory) kills

#### **4. Compliance & SLA** 📋
- **Uptime tracking** → Ensure 99.9% availability
- **Transaction success rate** → Ensure <0.1% failure rate
- **Response time SLAs** → Ensure p95 < 500ms

### **How Alert Rules Work**

#### **Rule Components**

**1. Expression (`expr`)**
- PromQL query that evaluates to true/false
- Examples:
  - `up == 0` = service is down
  - `rate(http_requests_total{code="500"}[5m]) > 0.1` = error rate too high
  - `cpu_usage > 0.9` = CPU usage > 90%

**2. Duration (`for`)**
- How long condition must be true before alerting
- Prevents false alarms from temporary spikes
- Example: `for: 2m` = fire alert only if condition persists for 2 minutes

**3. Labels**
- Metadata for routing/filtering alerts
- Examples:
  - `severity: critical` = page on-call engineer
  - `severity: warning` = send to Slack channel
  - `team: platform` = route to infrastructure team

**4. Annotations**
- Human-readable alert details
- `summary`: Brief description (shown in notifications)
- `description`: Detailed explanation with metric values

#### **Alert States**

- **Inactive**: Condition is false (no alert, everything OK)
- **Pending**: Condition is true, but `for` duration not met yet (watching...)
- **Firing**: Condition is true for required duration → Alert active (notify!)

### **PayFlow Alert Rule Groups**

PayFlow has **7 alert rule groups** covering all aspects of the application:

#### **1. Service Availability** 🟢
**Purpose**: Monitor if services are running
- `ServiceDown`: Service not responding for 2 minutes
- `HighPodRestartRate`: Services crashing frequently (>5 restarts/15min)

**Why Important**: If a service is down, users can't use that functionality.

#### **2. Error Rate** 🔴
**Purpose**: Monitor application errors
- `HighHTTPErrorRate`: Too many 4xx/5xx responses (>10% error rate)
- `High5xxErrorRate`: Server errors increasing (>5% 5xx errors)

**Why Important**: High error rates indicate bugs or system problems.

#### **3. Performance** ⚡
**Purpose**: Monitor response times and resource usage
- `HighResponseTime`: API responses too slow (P95 > 1 second)
- `HighMemoryUsage`: Memory consumption too high (>500MB per service)
- `HighCPUUsage`: CPU usage approaching limits (>80%)

**Why Important**: Slow services = unhappy users. High resource usage = potential crashes.

#### **4. Database** 💾
**Purpose**: Monitor database health
- `DatabaseConnectionPoolExhausted`: No available connections
- `SlowQueries`: Database queries taking too long (>1 second)

**Why Important**: Database issues can bring down the entire application.

#### **5. Business Metrics** 📊
**Purpose**: Monitor application-specific metrics
- `LowUserRegistrations`: Unusual drop in signups (<5/hour)
- `HighFailedLoginAttempts`: Possible brute force attack (>50 failed logins/min)

**Why Important**: Business metrics show if the application is healthy from a user perspective.

#### **6. Financial** 💰
**Purpose**: Monitor transaction-related metrics
- `HighTransactionVolume`: Unusual transaction spike (>10,000/hour)
- `WalletBalanceAnomaly`: Suspicious balance changes (>$10,000 delta)

**Why Important**: Financial anomalies can indicate fraud or system errors.

### **Alert Lifecycle**

1. **Prometheus Evaluates Rule** (every 15 seconds)
   - Checks if condition is true
   - If true for `for` duration → Alert fires

2. **AlertManager Receives Alert**
   - Processes alert metadata
   - Routes based on labels (severity, team)

3. **Notification Sent**
   - Email/Slack/SMS/PagerDuty
   - On-call engineer receives notification

4. **Alert Resolves**
   - Condition returns to normal
   - AlertManager sends resolution notification

### **Checking Alerts**

#### **View Active Alerts in Prometheus**
```bash
# Via curl
curl http://localhost:9090/api/v1/alerts

# Via Prometheus UI
# Visit: http://prometheus.gameapp.games/alerts
# Or: http://prometheus.payflow.local/alerts
```

#### **View Alert Rules**
```bash
# Via curl
curl http://localhost:9090/api/v1/rules

# Via Prometheus UI
# Visit: http://prometheus.gameapp.games/rules
```

#### **View Firing Alerts in AlertManager**
```bash
curl http://localhost:9093/api/v2/alerts
```

### **Best Practices for Alert Rules**

#### **✅ Good Alert Examples**
- **Actionable**: You can do something about it
  - ✅ Service is down → Restart service
  - ✅ Error rate > 5% → Check logs, fix bug
  - ✅ Response time > 1s → Scale up or optimize

#### **❌ Bad Alert Examples**
- **Not Actionable**: No clear action to take
  - ❌ CPU > 50% (normal under load)
  - ❌ Memory > 100MB (normal for Node.js)
  - ❌ Every single error (too noisy)

#### **Alert Threshold Guidelines**
- **Start Conservative**: Set thresholds higher initially
- **Adjust Based on Data**: Lower thresholds after observing normal behavior
- **Use `for` Duration**: Prevent false alarms (2-5 minutes minimum)
- **Group Related Alerts**: Keep alerts organized by category

---

## 🔧 **Prometheus Queries**

### **Basic Query Syntax**

Prometheus uses **PromQL** (Prometheus Query Language). Think of it like SQL for metrics.

#### **Simple Queries**
```promql
# Get current value
up

# Get value for specific service
up{job="api-gateway"}

# Calculate rate over time
rate(http_request_duration_seconds_count[5m])
```

#### **Common PayFlow Queries**

##### **Service Health**
```promql
# All services health
up

# Specific service health
up{job="api-gateway"}

# Services that are down
up == 0
```

##### **Request Metrics**
```promql
# Request rate per second
rate(http_request_duration_seconds_count[5m])

# Request rate for specific service
rate(http_request_duration_seconds_count{job="api-gateway"}[5m])

# Total requests
http_request_duration_seconds_count
```

##### **Response Time**
```promql
# Average response time
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# 95th percentile response time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

##### **Resource Usage**
```promql
# Memory usage
process_resident_memory_bytes

# CPU usage percentage
rate(process_cpu_seconds_total[5m]) * 100

# Memory usage in MB
process_resident_memory_bytes / 1024 / 1024
```

##### **Business Metrics**
```promql
# Transaction rate
rate(transactions_total[5m])

# Successful transactions
rate(transactions_total{status="completed"}[5m])

# Failed transactions
rate(transactions_total{status="failed"}[5m])
```

### **Testing Queries**

#### **Using Prometheus Web UI**
1. Go to http://localhost:9090
2. Click "Graph" tab
3. Enter your query
4. Click "Execute"

#### **Using curl**
```bash
# Test a query
curl "http://localhost:9090/api/v1/query?query=up"

# Test with URL encoding
curl "http://localhost:9090/api/v1/query?query=rate(http_request_duration_seconds_count%5B5m%5D)"
```

---

## 🎯 **Monitoring Best Practices**

### **What to Monitor**

#### **Golden Signals (Essential)**
1. **Latency**: How long requests take
2. **Traffic**: How many requests
3. **Errors**: How many failures
4. **Saturation**: How busy the system is

#### **Business Metrics**
1. **Transaction Volume**: Money moved
2. **User Activity**: Logins, registrations
3. **Revenue**: If applicable

### **Setting Up Monitoring**

#### **1. Start Simple**
- Monitor basic health (up/down)
- Monitor response times
- Monitor error rates

#### **2. Add Business Metrics**
- Transaction success rate
- User activity
- Revenue metrics

#### **3. Set Up Alerts**
- Start with critical alerts only
- Add warning alerts gradually
- Test alert notifications

### **Alert Fatigue Prevention**

#### **Don't Alert on Everything**
- Only alert on actionable issues
- Use warning vs critical levels
- Group related alerts

#### **Good Alert Examples**
- ✅ Service is down (actionable)
- ✅ Error rate > 5% (actionable)
- ✅ Response time > 1s (actionable)

#### **Bad Alert Examples**
- ❌ CPU > 50% (not actionable)
- ❌ Memory > 100MB (not actionable)
- ❌ Every error (too noisy)

---

## 🚀 **Next Steps**

### **Immediate Actions**
1. **Explore Grafana Dashboard**: http://localhost:3006
2. **Check Prometheus Metrics**: http://localhost:9090
3. **View Active Alerts**: http://localhost:9093
4. **Test Some Queries**: Try the examples above

### **Learning Path**
1. **Understand Metrics**: Learn what each metric means
2. **Practice Queries**: Write PromQL queries
3. **Set Up Alerts**: Configure alert rules
4. **Create Dashboards**: Build custom visualizations

### **Production Readiness**
1. **Set Up Notifications**: Email/Slack alerts
2. **Create Runbooks**: What to do when alerts fire
3. **Test Alerting**: Simulate failures
4. **Monitor Business Metrics**: Track KPIs

---

## 📚 **Additional Resources**

### **Prometheus Documentation**
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)

### **Grafana Documentation**
- [Dashboard Creation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Panel Types](https://grafana.com/docs/grafana/latest/panels/)

### **Monitoring Best Practices**
- [Google SRE Book](https://sre.google/sre-book/monitoring-distributed-systems/)
- [The Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)

**Remember: Monitoring is not just about collecting data - it's about understanding your system and being able to respond quickly when things go wrong!**
