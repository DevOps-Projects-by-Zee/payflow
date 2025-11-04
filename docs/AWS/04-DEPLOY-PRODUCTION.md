# Deploy Production - Building the Luxury Homes

**⏱️ Time: 30 minutes**

**The Story**: Now you're building the Production environment - where real customers will use your application. This is like building luxury homes that need to be perfect, reliable, and available 24/7. Think of it as the premium neighborhood! 🏡

**⚠️ Prerequisite**: Hub must be deployed first. Production depends on Hub for VPC peering and shared services. It's like you need the main roads (Hub) built before you can build houses (Production) that connect to them.

---

## Step 1: Get Hub Outputs (Getting the Addresses)

**The Story**: Before building Production, you need to know where the Hub is located. It's like needing the main road address before you can connect your new neighborhood to it.

**What We're Doing**: Getting connection information from Hub so Production can connect to shared services.

```bash
cd terraform/environments/hub

# Get Hub outputs needed for Production
# Like getting the address and phone number of the main building
terraform output terraform_state_bucket  # The filing cabinet location
terraform output vpc_id                  # The Hub's network address
terraform output bastion_security_group_id  # The security gate's ID
```

**Save these values** - you'll need them in Step 2.

**Why This Matters**: Production needs to know:
- Where to store its blueprint (terraform_state_bucket)
- How to connect to Hub's network (vpc_id)
- What security rules to follow (bastion_security_group_id)

**Analogy**: Like getting the master key, building address, and security code before building a new wing of a building.

---

## Step 2: Deploy Production Environment (Building the Luxury Homes)

**The Story**: Now you're actually building! Production is like a luxury apartment complex:
- Multiple availability zones (like having backups in different locations)
- High availability (if one area fails, others keep running)
- Premium performance (faster, more reliable)

```bash
cd terraform/environments/production

# Copy example variables (if not exists)
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
# Think of this as filling out the building permit form for Production
# Required values:
# - terraform_state_bucket: Get from Hub outputs (Step 1)
#   This tells Production where to store its blueprint
# - Other values can use defaults or examples

# Initialize Terraform (loading your toolbox)
terraform init -backend-config=backend-config.hcl

# Review plan (reviewing the blueprint before building)
terraform plan
# This shows you EXACTLY what Production will create. Review carefully!

# Apply changes (actually building - takes ~25-30 minutes)
terraform apply
# Say "yes" when prompted, then grab coffee - this takes a while! ☕
```

**What Gets Created** (The Luxury Building Features):

**Networking** (The Premium Roads):
- Production VPC (10.1.0.0/16) - Your private network
- Public/private subnets (3 availability zones) - Like having roads in 3 different areas for redundancy
- NAT Gateways (3x Multi-AZ) - Premium internet connections in each area
- VPC peering connection to Hub - The bridge to shared services
- Route table updates - Traffic directions

**Compute** (The Premium Buildings):
- EKS cluster (Multi-AZ, On-Demand instances) - Premium Kubernetes setup
- EKS node group (3x t3.medium) - Strong, reliable workers
- No interruptions (On-Demand means stable, always available)

**Storage** (The Premium Storage):
- RDS PostgreSQL (Multi-AZ, db.t3.small) - Database with automatic backups
- ElastiCache Redis (Multi-AZ, 2 nodes) - Super-fast cache with redundancy
- Secrets Manager secrets (PostgreSQL, Redis, JWT, RabbitMQ) - Secure storage for passwords

**The Difference from Hub**: Production uses Multi-AZ (multiple availability zones) for everything. If one zone has issues, others keep running. It's like having backup systems in different locations.

**Expected Output** (Success Looks Like This):
```
Apply complete! Resources: 35 added, 0 changed, 0 destroyed.

Outputs:
eks_cluster_id = "payflow-production-eks"  ← Your Production cluster
rds_endpoint = "payflow-production-postgres.xxxxx.rds.amazonaws.com"  ← Database address
redis_endpoint = "payflow-production-redis.xxxxx.cache.amazonaws.com"  ← Cache address
```

**🎉 Congratulations!** You've built the Production environment!

---

## Step 3: Verify Production Deployment (The Quality Inspection)

**The Story**: Before celebrating, let's inspect everything. Like a building inspector checking that the luxury homes are built correctly.

```bash
# Check EKS cluster (the main building)
aws eks describe-cluster --name payflow-production-eks
# Should show status: ACTIVE ✅

# Check RDS (the database - like the building's filing system)
aws rds describe-db-instances \
  --db-instance-identifier payflow-production-postgres
# Should show Multi-AZ: enabled, Status: available ✅

# Check Redis (the fast cache - like the building's quick reference)
aws elasticache describe-replication-groups \
  --replication-group-id payflow-production-redis
# Should show Multi-AZ: enabled, Status: available ✅

# Check VPC peering (the bridge to Hub)
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active"
# Should show peering status: active ✅
```

**Success Criteria** (The Inspection Checklist):
- ✅ EKS cluster: ACTIVE (the building is operational)
- ✅ RDS: Multi-AZ, available (the database has backups)
- ✅ Redis: Multi-AZ, available (the cache has redundancy)
- ✅ VPC peering: active (the bridge to Hub is working)

**🎉 If all checks pass, Production is ready for applications!**

---

## Step 4: Configure kubectl for Production (Getting Your Access Card)

**The Story**: You've built the secure building, now you need an access card to get in. The bastion host is your security guard.

```bash
# Get bastion IP from Hub (the security gate address)
cd ../hub
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH to bastion (like calling the security guard)
ssh -i payflow-bastion.pem ec2-user@${BASTION_IP}

# On bastion, configure kubectl for Production
# Like getting your access card programmed for the Production building
aws eks update-kubeconfig \
  --region us-east-1 \
  --name payflow-production-eks

# Verify cluster access (testing your access card)
kubectl get nodes
```

**Expected Output** (Your Access Card Works!):
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-1-10-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
ip-10-1-11-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
ip-10-1-12-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

**What This Means**: 
- ✅ Production cluster is running
- ✅ You have 3 worker nodes (Multi-AZ for reliability)
- ✅ You can now deploy Production applications!

**The Difference**: Production has 3 nodes across 3 availability zones. If one zone fails, you still have 2 nodes running. This is high availability!

---

## ⚠️ Troubleshooting (When Things Go Wrong)

### Error: "Failed to read remote state"

**The Problem**: Production can't find Hub's blueprint.

**The Solution**: Hub must be deployed first.
```bash
# Verify Hub exists
cd ../hub && terraform output vpc_id
# Should show a VPC ID. If not, deploy Hub first!
```

**Analogy**: Like trying to connect to a building that doesn't exist yet.

---

### Error: "VPC peering connection failed"

**The Problem**: The bridge between Production and Hub isn't working.

**The Solution**:
1. Check both VPCs are in same region (like both buildings in same city)
2. Check security groups allow peering traffic (like security guards need to communicate)
3. Verify route tables have peering routes (like having directions between buildings)

**Analogy**: Like building a bridge but forgetting to connect the roads on both sides.

---

### Error: "RDS subnet group not found"

**The Problem**: RDS needs subnets in multiple availability zones for Multi-AZ.

**The Solution**: Ensure subnets span multiple AZs. Production requires Multi-AZ for high availability - it's a requirement, not optional.

**Analogy**: Like trying to build a backup system but only having one location.

---

### Error: "External Secrets not syncing"

**The Problem**: Applications can't get secrets from AWS Secrets Manager.

**The Solution**:
1. Check ESO is installed: `kubectl get pods -n external-secrets-system`
2. Verify IAM role has Secrets Manager permissions (like checking the security guard has the right key)
3. Check secret ARNs are correct in `external-secrets.yaml`
4. Review ESO logs: `kubectl logs -n external-secrets-system deployment/external-secrets-operator`

**Analogy**: Like having a vault but the security guard doesn't have the master key.

---

## 💡 Production vs Development: The Difference

**Production** (What You Just Built):
- **Reliability**: Multi-AZ (backups in multiple locations)
- **Performance**: On-Demand instances (always available)
- **Cost**: ~$305/month (premium features)
- **Use Case**: Real customers, real money, real transactions

**Development** (Coming Next):
- **Reliability**: Single-AZ (one location, cheaper)
- **Performance**: Spot instances (can be interrupted, much cheaper)
- **Cost**: ~$50/month (cost-optimized)
- **Use Case**: Testing, experiments, learning

**Analogy**:
- Production = A luxury car with backup engine, premium tires, full insurance
- Development = A project car for weekend tinkering

---

## 🎉 What's Next?

You've successfully built the Production environment! Production is now:
- ✅ Running with high availability (Multi-AZ)
- ✅ Connected to Hub (can use shared services)
- ✅ Secure (private endpoints, bastion access)
- ✅ Ready for real customer traffic!

**Ready to build the Development environment?** → [Next: Deploy Development](./05-DEPLOY-DEVELOPMENT.md)

**Or want to learn more?** → [Reference Guide](./99-REFERENCE.md)
