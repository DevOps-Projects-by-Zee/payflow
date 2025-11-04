# Deploy Development - Building the Starter Homes

**⏱️ Time: 20 minutes**

**The Story**: Now you're building the Development environment - where you experiment, test, and learn. This is like building starter homes or a workshop where it's okay if things break sometimes. Think of it as the affordable neighborhood where you can try new things! 🏠

**⚠️ Prerequisite**: Hub must be deployed first. Development depends on Hub for VPC peering and shared services. Like needing the main roads before building your workshop.

**Note**: Development is **cost-optimized** with Single-AZ and Spot instances. This is acceptable for non-production workloads. If it breaks, you can rebuild it quickly!

---

## Step 1: Deploy Development Environment (Building the Workshop)

**The Story**: Development is your experimental space. Unlike Production (where everything must be perfect), Development can be simpler and cheaper:
- Single availability zone (one location is fine for testing)
- Spot instances (cheaper, but can be interrupted - that's okay for dev!)
- Smaller resources (you don't need production-level power for testing)

```bash
cd terraform/environments/development

# Copy example variables (if not exists)
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
# Same bucket as production from Hub - they share the same filing cabinet

# Initialize Terraform (loading your toolbox)
terraform init -backend-config=backend-config.hcl

# Deploy (actually building - faster than Production!)
terraform apply
# Say "yes" when prompted. This goes faster than Production! ⚡
```

**What Gets Created** (The Cost-Optimized Features):

**Networking** (The Budget Roads):
- Development VPC (10.2.0.0/16) - Your private network
- Public/private subnets (single AZ) - One location is fine!
- NAT Gateway (1x - cost optimization) - One connection instead of three
- VPC peering connection to Hub - The bridge to shared services

**Compute** (The Budget Buildings):
- EKS cluster (Single-AZ, Spot instances) - Cheaper Kubernetes setup
- EKS node group (1x t3.small Spot) - One worker is enough for testing
- Spot instances = Can be interrupted, but 50-70% cheaper!

**Storage** (The Budget Storage):
- RDS PostgreSQL (Single-AZ, db.t3.micro) - Smaller database, no backups needed
- ElastiCache Redis (Single node) - One cache node is enough
- Secrets Manager secrets - Same secure storage

**Cost Optimizations** (The Savings):
- Single NAT Gateway (save $64/month) - One instead of three
- Spot instances (save $15/month) - Interruptible but cheap
- Single-AZ RDS (save $30/month) - No backup needed for testing
- Single Redis node (save $7.50/month) - One is enough

**Trade-offs** (What You're Giving Up):
- Less HA (acceptable for development) - If it breaks, rebuild it
- Spot instances can be interrupted (acceptable for dev) - Just redeploy

**Expected Output** (Success Looks Like This):
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
eks_cluster_id = "payflow-development-eks"  ← Your Development cluster
rds_endpoint = "payflow-development-postgres.xxxxx.rds.amazonaws.com"  ← Database address
redis_endpoint = "payflow-development-redis.xxxxx.cache.amazonaws.com"  ← Cache address
```

**🎉 Congratulations!** You've built the Development environment!

**The Difference**: Development uses 25 resources vs Production's 35. It's simpler, cheaper, and faster to build. Perfect for testing!

---

## Step 2: Verify Development Deployment (The Quick Check)

**The Story**: Let's quickly check that everything works. Development doesn't need the same thorough inspection as Production - it's a workshop, not a luxury home.

```bash
# Check EKS cluster (the workshop is operational)
aws eks describe-cluster --name payflow-development-eks
# Should show status: ACTIVE ✅

# Check RDS (the test database)
aws rds describe-db-instances \
  --db-instance-identifier payflow-development-postgres
# Should show Single-AZ: true, Status: available ✅

# Check Redis (the test cache)
aws elasticache describe-replication-groups \
  --replication-group-id payflow-development-redis
# Should show status: available ✅
```

**Success Criteria** (The Quick Checklist):
- ✅ EKS cluster: ACTIVE (workshop is operational)
- ✅ RDS: Single-AZ, available (test database works)
- ✅ Redis: available (test cache works)

**🎉 If all checks pass, Development is ready for testing!**

---

## Step 3: Configure kubectl for Development (Getting Your Access Card)

**The Story**: Same as Production - you need an access card to get into your Development workshop.

```bash
# Get bastion IP from Hub (the security gate address)
cd ../hub
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH to bastion (like calling the security guard)
ssh -i payflow-bastion.pem ec2-user@${BASTION_IP}

# On bastion, configure kubectl for Development
# Like getting your access card programmed for the Development workshop
aws eks update-kubeconfig \
  --region us-east-1 \
  --name payflow-development-eks

# Verify cluster access (testing your access card)
kubectl get nodes
```

**Expected Output** (Your Access Card Works!):
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-2-10-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

**What This Means**: 
- ✅ Development cluster is running
- ✅ You have 1 worker node (enough for testing)
- ✅ You can now deploy Development applications!

**The Difference**: Development has 1 node vs Production's 3 nodes. That's fine - you're just testing!

---

## 💰 Scale-to-Zero (The Vacation Mode Story)

**The Story**: You're going on vacation or taking a break from development. Why pay $72/month for Development when you're not using it? 

**Scale-to-Zero**: Turn off Development when you're not using it, like turning off lights when you leave the house.

**Save money when you're not actively developing:**

```bash
# Destroy development environment (like turning off all the lights)
cd terraform/environments/development
terraform destroy
# Say "yes" when prompted. This deletes everything.

# Recreate when needed (like turning the lights back on)
terraform apply
# Takes ~20 minutes to rebuild - acceptable for dev!
```

**Savings**: $72/month (EKS control plane) + node costs

**Recreation Time**: ~20 minutes (acceptable for dev environment)

**When to Use Scale-to-Zero**:
- ✅ Going on vacation
- ✅ Taking a break from development
- ✅ Learning phase is complete
- ✅ Saving money while not actively coding

**When NOT to Use Scale-to-Zero**:
- ❌ Actively developing (you need it running)
- ❌ Running demos or tests
- ❌ Sharing with team members

**Analogy**: 
- Always On: Like leaving your workshop lights on 24/7
- Scale-to-Zero: Like turning everything off when you're away

**Pro Tip**: You can destroy and recreate Development in ~20 minutes. It's designed to be disposable!

---

## ⚠️ Troubleshooting (When Things Go Wrong)

### Error: "Spot instance capacity not available"

**The Problem**: AWS doesn't have Spot capacity available right now.

**The Solution**:
1. Wait 5-10 minutes and try again (capacity changes constantly)
2. Or change `capacity_type` to `"ON_DEMAND"` in `terraform.tfvars`
3. Note: This will increase costs (~$15/month), but gives stability

**Analogy**: Like trying to rent a cheap parking spot, but they're all taken. Wait a bit or pay for reserved parking.

---

### Error: "Spot instance terminated unexpectedly"

**The Problem**: AWS needed your Spot instance back (someone paid more for it).

**The Solution**: This is normal for Spot instances! Just redeploy:
```bash
terraform apply
```

**Or switch to ON_DEMAND for stability** (higher cost but no interruptions):
```bash
# In terraform.tfvars, change:
capacity_type = "ON_DEMAND"
```

**Analogy**: 
- Spot = Renting a parking spot that can be taken away
- ON_DEMAND = Reserved parking that's always yours

**The Trade-off**: 
- Spot: Cheap but can be interrupted (fine for dev)
- ON_DEMAND: More expensive but stable (better for production)

---

### All Other Errors

**See [Troubleshooting Guide](../TROUBLESHOOTING.md)** for common issues and solutions.

**Or check**: [99-REFERENCE.md](./99-REFERENCE.md) for links to detailed guides.

---

## 💡 Development: The Cost-Effective Choice

**Why Development Costs Less**:

| Feature | Production | Development | Savings |
|---------|-----------|------------|---------|
| NAT Gateways | 3x (Multi-AZ) | 1x (Single) | $64/month |
| Instances | On-Demand | Spot | $15/month |
| RDS | Multi-AZ | Single-AZ | $30/month |
| Redis | 2 nodes | 1 node | $7.50/month |
| **Total** | **$305/month** | **~$50/month** | **$255/month** |

**The Philosophy**: 
- Production = Premium everything (reliability is critical)
- Development = Good enough (it's okay if it breaks)

**Analogy**:
- Production = Luxury car (premium everything)
- Development = Project car (gets the job done, cheaper to maintain)

---

## 🎉 What's Next?

You've successfully built all three environments! You now have:
- ✅ **Hub** - The foundation (shared services)
- ✅ **Production** - The luxury homes (customer-facing)
- ✅ **Development** - The workshop (testing and learning)

**Complete Setup**:
- Total time: ~2 hours
- Total cost: ~$530/month (or $458/month with dev scaled to zero)
- What you learned: Production-grade AWS infrastructure!

**Next Steps**:
- Deploy applications to Kubernetes
- Configure secrets sync
- Set up monitoring
- Learn more from the reference guides

**Ready to learn more?** → [Reference Guide](./99-REFERENCE.md)

**Want to deploy applications?** → Check your Kubernetes manifests and start deploying!

---

**🎊 Congratulations! You've built a complete production-grade infrastructure!** 🎊
