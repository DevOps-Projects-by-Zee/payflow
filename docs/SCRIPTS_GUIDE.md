# Scripts Usage Guide

## ⚠️ **Important: Manual First Approach**

**Scripts are provided for convenience AFTER you understand the manual deployment process.**

### **Why Manual First?**

1. **Learning**: You need to understand what each command does
2. **Troubleshooting**: When things go wrong, you need to know how to fix them
3. **Career Growth**: Employers want engineers who understand the underlying processes
4. **Confidence**: Manual understanding builds confidence in automation

### **When to Use Scripts**

✅ **Use Scripts When:**
- You've completed manual deployments successfully
- You understand what each step does
- You need to repeat deployments frequently
- You're setting up CI/CD pipelines
- You're demonstrating the system to others

❌ **Don't Use Scripts When:**
- You're learning the system for the first time
- You're troubleshooting issues
- You need to understand what's happening
- You're preparing for interviews

---

## 📋 **Available Scripts**

### **Setup Scripts**

#### `./scripts/setup.sh`
**Purpose**: Complete Docker Compose setup
**When to use**: After understanding manual Docker Compose deployment
```bash
# What it does:
# 1. Starts infrastructure services
# 2. Runs database migrations
# 3. Starts all application services
# 4. Starts monitoring stack
# 5. Verifies all services are healthy

./scripts/setup.sh
```

#### `./scripts/create-user.sh`
**Purpose**: Create test users for development
**When to use**: After services are running
```bash
# What it does:
# 1. Registers a test user
# 2. Creates a wallet
# 3. Adds initial balance
# 4. Returns user credentials

./scripts/create-user.sh
```

### **Deployment Scripts**

#### `./scripts/deploy-k8s.sh`
**Purpose**: Deploy to k3d Kubernetes cluster
**When to use**: After understanding manual k3d deployment
```bash
# What it does:
# 1. Creates k3d cluster
# 2. Applies Kubernetes manifests
# 3. Waits for deployments
# 4. Verifies services

./scripts/deploy-k8s.sh
```

#### `./scripts/deploy-aws.sh`
**Purpose**: Deploy to AWS EKS
**When to use**: After understanding manual AWS deployment
```bash
# What it does:
# 1. Creates EKS cluster
# 2. Configures kubectl
# 3. Deploys services
# 4. Sets up Load Balancer

./scripts/deploy-aws.sh
```

#### `./scripts/deploy-azure.sh`
**Purpose**: Deploy to Azure AKS
**When to use**: After understanding manual Azure deployment
```bash
# What it does:
# 1. Creates AKS cluster
# 2. Configures kubectl
# 3. Deploys services
# 4. Sets up Load Balancer

./scripts/deploy-azure.sh
```

### **Operations Scripts**

#### `./scripts/monitor.sh`
**Purpose**: System monitoring dashboard
**When to use**: Anytime after services are running
```bash
# What it does:
# 1. Checks service health
# 2. Shows metrics
# 3. Displays monitoring URLs
# 4. Provides quick commands

./scripts/monitor.sh
```

#### `./scripts/scale-service.sh`
**Purpose**: Scale services up/down
**When to use**: For load testing or capacity planning
```bash
# Scale wallet service to 3 replicas
./scripts/scale-service.sh wallet-service 3

# Scale API gateway to 5 replicas
./scripts/scale-service.sh api-gateway 5
```

#### `./scripts/load-test.sh`
**Purpose**: Generate load for testing
**When to use**: For performance testing
```bash
# What it does:
# 1. Generates HTTP requests
# 2. Creates transactions
# 3. Monitors performance
# 4. Reports results

./scripts/load-test.sh
```

#### `./scripts/security-scan.sh`
**Purpose**: Security vulnerability scanning
**When to use**: Before production deployment
```bash
# What it does:
# 1. Scans dependencies
# 2. Checks Docker images
# 3. Analyzes code
# 4. Reports vulnerabilities

./scripts/security-scan.sh
```

### **Maintenance Scripts**

#### `./scripts/backup-db.sh`
**Purpose**: Backup database
**When to use**: Regular maintenance
```bash
# What it does:
# 1. Creates database backup
# 2. Compresses backup
# 3. Stores with timestamp
# 4. Verifies backup

./scripts/backup-db.sh
```

#### `./scripts/restore-db.sh`
**Purpose**: Restore database from backup
**When to use**: Disaster recovery
```bash
# Restore from specific backup
./scripts/restore-db.sh backup-2024-01-15.sql
```

#### `./scripts/cleanup.sh`
**Purpose**: Clean up resources
**When to use**: After testing or development
```bash
# What it does:
# 1. Stops containers
# 2. Removes volumes
# 3. Cleans up images
# 4. Removes logs

./scripts/cleanup.sh
```

---

## 🎯 **Learning Path with Scripts**

### **Phase 1: Manual Learning (Required)**
1. **Docker Compose**: Complete manual deployment
2. **k3d**: Complete manual Kubernetes deployment
3. **AWS/Azure**: Complete manual cloud deployment
4. **Troubleshooting**: Fix issues manually

### **Phase 2: Script Understanding (Recommended)**
1. **Read Scripts**: Understand what each script does
2. **Modify Scripts**: Customize for your needs
3. **Test Scripts**: Run scripts and verify results
4. **Debug Scripts**: Fix script issues

### **Phase 3: Automation (Advanced)**
1. **CI/CD Integration**: Use scripts in pipelines
2. **Custom Scripts**: Create your own automation
3. **Monitoring**: Integrate with monitoring systems
4. **Production**: Use scripts for production operations

---

## 🔧 **Script Customization**

### **Environment Variables**
Most scripts support environment variables for customization:

```bash
# Customize cluster name
export CLUSTER_NAME=my-payflow-cluster
./scripts/deploy-k8s.sh

# Customize region
export AWS_REGION=us-east-1
./scripts/deploy-aws.sh

# Customize node count
export NODE_COUNT=5
./scripts/deploy-k8s.sh
```

### **Configuration Files**
Scripts read from configuration files:

```bash
# Docker Compose configuration
docker-compose.yml

# Kubernetes manifests
k8s/

# Monitoring configuration
monitoring/

# Script configuration
scripts/config/
```

---

## 🚨 **Troubleshooting Scripts**

### **Common Script Issues**

#### **Permission Denied**
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run with proper permissions
./scripts/setup.sh
```

#### **Dependencies Missing**
```bash
# Check required tools
which docker
which kubectl
which aws

# Install missing tools
brew install docker kubectl awscli
```

#### **Script Fails**
```bash
# Run with verbose output
bash -x ./scripts/setup.sh

# Check script logs
tail -f /tmp/payflow-setup.log
```

### **Debug Mode**
Most scripts support debug mode:

```bash
# Enable debug output
export DEBUG=true
./scripts/setup.sh

# Verbose logging
export VERBOSE=true
./scripts/deploy-k8s.sh
```

---

## 📚 **Best Practices**

### **Before Using Scripts**
1. ✅ Complete manual deployment
2. ✅ Understand each step
3. ✅ Test in non-production environment
4. ✅ Read script documentation
5. ✅ Check script prerequisites

### **When Using Scripts**
1. ✅ Run in test environment first
2. ✅ Monitor script execution
3. ✅ Verify results manually
4. ✅ Keep logs for troubleshooting
5. ✅ Have rollback plan ready

### **After Using Scripts**
1. ✅ Verify all services are running
2. ✅ Test application functionality
3. ✅ Check monitoring dashboards
4. ✅ Document any customizations
5. ✅ Update scripts if needed

---

## 🎓 **Career Value**

### **Manual Skills (Essential)**
- Understanding containerization
- Kubernetes concepts
- Cloud platform knowledge
- Troubleshooting techniques
- System architecture

### **Automation Skills (Advanced)**
- Script development
- CI/CD pipeline design
- Infrastructure as Code
- Monitoring and alerting
- Production operations

**Remember: Manual understanding is the foundation for automation mastery!**
