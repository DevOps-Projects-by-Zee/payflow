# Production Operations Guide

## 🎯 **Production Operations**

This guide covers essential operational procedures for running PayFlow in production, including blue-green deployment strategies.

---

## 🚀 **Blue-Green Deployment Strategy**

### **What is Blue-Green Deployment?**

Blue-Green deployment is a **zero-downtime deployment strategy** where you maintain two identical production environments:

- **Blue Environment**: Currently serving live traffic
- **Green Environment**: Standby environment for new deployments

### **Why Blue-Green for PayFlow?**

For a fintech application like PayFlow, blue-green deployment is **essential** because:

- ✅ **Zero Downtime**: Financial transactions can't be interrupted
- ✅ **Instant Rollback**: Switch back if issues detected
- ✅ **Full Testing**: Test new version before traffic switch
- ✅ **Compliance**: Meets financial service uptime requirements
- ✅ **User Trust**: Seamless experience builds confidence

### **How Blue-Green Works**

#### **Step 1: Deploy to Green**
```bash
# Deploy new version to green environment
kubectl set image deployment/api-gateway-green api-gateway=payflow/api-gateway:v1.2.3 -n payflow
kubectl scale deployment/api-gateway-green --replicas=3 -n payflow
```

#### **Step 2: Test Green Environment**
```bash
# Test green environment
kubectl port-forward svc/api-gateway-green 3001:3000 -n payflow &
curl http://localhost:3001/health
```

#### **Step 3: Switch Traffic**
```bash
# Update ingress to point to green
kubectl patch ingress payflow-ingress -n payflow -p '{"spec":{"rules":[{"host":"payflow.com","http":{"paths":[{"path":"/","backend":{"service":{"name":"api-gateway-green","port":{"number":3000}}}}]}}]}}'
```

#### **Step 4: Monitor and Cleanup**
```bash
# Monitor for issues
kubectl logs -f deployment/api-gateway-green -n payflow

# If successful, scale down blue
kubectl scale deployment/api-gateway-blue --replicas=0 -n payflow
```

---

## 🚀 **Deployment Operations**

### **Blue-Green Deployment**

#### **Deploy New Version**
```bash
# Deploy API Gateway
make deploy SERVICE=api-gateway VERSION=v1.2.3

# Deploy Wallet Service
make deploy SERVICE=wallet-service VERSION=v2.1.0

# Deploy Transaction Service
make deploy SERVICE=transaction-service VERSION=v1.5.0
```

#### **Check Deployment Status**
```bash
# Check specific service
make status SERVICE=api-gateway

# Check all services
kubectl get deployments -n payflow
kubectl get pods -n payflow
```

#### **Rollback if Needed**
```bash
# Rollback to previous version
make rollback SERVICE=api-gateway
```

---

## 📊 **Monitoring Operations**

### **Health Checks**

#### **Service Health**
```bash
# Check API Gateway health
curl http://localhost:3000/health

# Check all services
kubectl get pods -n payflow
kubectl describe pods -n payflow
```

#### **Database Health**
```bash
# Check PostgreSQL
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "SELECT 1"

# Check Redis
kubectl exec -it redis-0 -n payflow -- redis-cli ping
```

#### **Message Queue Health**
```bash
# Check RabbitMQ
kubectl exec -it rabbitmq-0 -n payflow -- rabbitmqctl status
```

### **Metrics and Logs**

#### **View Metrics**
```bash
# Access Prometheus
kubectl port-forward service/prometheus 9090:9090 -n payflow
# Open: http://localhost:9090

# Access Grafana
kubectl port-forward service/grafana 3005:3000 -n payflow
# Open: http://localhost:3005 (admin/admin)
```

#### **View Logs**
```bash
# View service logs
kubectl logs -f deployment/api-gateway-blue -n payflow
kubectl logs -f deployment/wallet-service-blue -n payflow

# View all logs
make logs
```

---

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Service Won't Start**
```bash
# Check pod status
kubectl get pods -n payflow
kubectl describe pod <pod-name> -n payflow

# Check logs
kubectl logs <pod-name> -n payflow

# Restart service
kubectl rollout restart deployment/<service-name> -n payflow
```

#### **Database Connection Issues**
```bash
# Check database status
kubectl get pods -n payflow -l app=postgres
kubectl logs postgres-0 -n payflow

# Test connection
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow
```

#### **High Memory Usage**
```bash
# Check resource usage
kubectl top pods -n payflow
kubectl top nodes

# Scale service
kubectl scale deployment/api-gateway-blue --replicas=5 -n payflow
```

#### **Slow Response Times**
```bash
# Check metrics
kubectl port-forward service/prometheus 9090:9090 -n payflow
# Query: rate(http_request_duration_seconds[5m])

# Check logs for errors
kubectl logs -f deployment/api-gateway-blue -n payflow | grep ERROR
```

---

## 🔒 **Security Operations**

### **Authentication Issues**

#### **JWT Token Problems**
```bash
# Check Redis token blacklist
kubectl exec -it redis-0 -n payflow -- redis-cli keys "*token*"

# Check auth service logs
kubectl logs -f deployment/auth-service-blue -n payflow
```

#### **User Lockouts**
```bash
# Check user status
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "SELECT email, locked_until FROM users WHERE locked_until > NOW();"

# Unlock user
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "UPDATE users SET locked_until = NULL WHERE email = 'user@example.com';"
```

### **Network Security**

#### **Check Network Policies**
```bash
# View network policies
kubectl get networkpolicies -n payflow
kubectl describe networkpolicy payflow-network-policy -n payflow
```

#### **Check Service Access**
```bash
# Test service connectivity
kubectl exec -it api-gateway-blue-xxx -n payflow -- curl http://wallet-service-service:3002/health
```

---

## 💾 **Backup and Recovery**

### **Database Backup**

#### **Create Backup**
```bash
# Backup PostgreSQL
kubectl exec -it postgres-0 -n payflow -- pg_dump -U payflow payflow > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup Redis
kubectl exec -it redis-0 -n payflow -- redis-cli BGSAVE
```

#### **Restore Backup**
```bash
# Restore PostgreSQL
kubectl exec -i postgres-0 -n payflow -- psql -U payflow payflow < backup_20231201_120000.sql
```

### **Configuration Backup**

#### **Backup ConfigMaps and Secrets**
```bash
# Backup configurations
kubectl get configmaps -n payflow -o yaml > configmaps_backup.yaml
kubectl get secrets -n payflow -o yaml > secrets_backup.yaml
```

---

## 📈 **Performance Optimization**

### **Resource Optimization**

#### **Check Resource Usage**
```bash
# Check pod resources
kubectl top pods -n payflow
kubectl describe pods -n payflow | grep -A 5 "Requests\|Limits"
```

#### **Scale Services**
```bash
# Scale based on load
kubectl scale deployment/api-gateway-blue --replicas=5 -n payflow
kubectl scale deployment/wallet-service-blue --replicas=3 -n payflow
```

### **Database Optimization**

#### **Check Database Performance**
```bash
# Check slow queries
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

#### **Optimize Queries**
```bash
# Check table sizes
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

---

## 🚨 **Incident Response**

### **Service Down**

#### **Check Service Status**
```bash
# Check all services
kubectl get pods -n payflow
kubectl get services -n payflow

# Check specific service
kubectl describe pod <pod-name> -n payflow
```

#### **Restart Service**
```bash
# Restart deployment
kubectl rollout restart deployment/api-gateway-blue -n payflow

# Check rollout status
kubectl rollout status deployment/api-gateway-blue -n payflow
```

### **High Error Rate**

#### **Check Error Metrics**
```bash
# Access Prometheus
kubectl port-forward service/prometheus 9090:9090 -n payflow
# Query: rate(http_requests_total{status=~"5.."}[5m])
```

#### **Check Logs**
```bash
# Check error logs
kubectl logs -f deployment/api-gateway-blue -n payflow | grep ERROR
```

### **Database Issues**

#### **Check Database Status**
```bash
# Check PostgreSQL
kubectl get pods -n payflow -l app=postgres
kubectl logs postgres-0 -n payflow

# Check connections
kubectl exec -it postgres-0 -n payflow -- psql -U payflow -d payflow -c "SELECT count(*) FROM pg_stat_activity;"
```

---

## 📋 **Operational Checklist**

### **Daily Operations**
- [ ] Check service health
- [ ] Monitor error rates
- [ ] Check resource usage
- [ ] Review logs for issues
- [ ] Verify backups

### **Weekly Operations**
- [ ] Review performance metrics
- [ ] Check security logs
- [ ] Update dependencies
- [ ] Test backup restoration
- [ ] Review capacity planning

### **Monthly Operations**
- [ ] Security audit
- [ ] Performance optimization
- [ ] Cost analysis
- [ ] Disaster recovery testing
- [ ] Documentation updates

---

## 🎯 **Key Metrics to Monitor**

### **Application Metrics**
- **Response Time**: < 200ms for 95% of requests
- **Error Rate**: < 0.1% of requests
- **Throughput**: Requests per second
- **Availability**: 99.9% uptime

### **Infrastructure Metrics**
- **CPU Usage**: < 80% average
- **Memory Usage**: < 80% average
- **Disk Usage**: < 80% capacity
- **Network Latency**: < 10ms

### **Business Metrics**
- **Transaction Volume**: Daily transaction count
- **User Activity**: Active users per day
- **Revenue Impact**: Transaction value
- **User Satisfaction**: Response time impact

---

**This operations guide provides essential procedures for running PayFlow in production! 🚀**
