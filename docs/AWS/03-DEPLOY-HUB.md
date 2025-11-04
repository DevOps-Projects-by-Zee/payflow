# Deploy Hub - Building the Foundation

**⏱️ Time: 45 minutes**

**The Story**: You're about to build the foundation of your cloud city - the Hub. This is the central building that all other environments will connect to. Let's build it step by step! 🏗️

The Hub contains all shared services that Production and Development environments will use. **This must be deployed first** - you can't build houses without the foundation!

---

## Step 1: Initialize Terraform Backend (The Filing Cabinet Setup)

**The Story**: Before building anything, you need a filing cabinet to store your blueprints (Terraform state). This filing cabinet needs:
- A secure lock (encryption)
- Version history (so you can see what changed)
- A way to prevent two people from editing at the same time (state locking)

**Purpose**: Create S3 bucket and DynamoDB table for Terraform state storage  
**Why**: Enables collaboration, state locking, versioning  
**Cost**: ~$1/month (very cheap!)

**Automated (Recommended - The Easy Way)**:
```bash
# Run initialization script
scripts/terraform/init-backend.sh

# This script does everything automatically:
# 1. Creates S3 bucket for state (like a filing cabinet)
# 2. Enables versioning and encryption (security)
# 3. Creates DynamoDB table for locking (prevents conflicts)
# 4. Creates KMS key for encryption (like a lock)
# 5. Updates backend-config.hcl files automatically (saves you time!)
```

**Verify**: Check that `terraform/environments/hub/backend-config.hcl` file has been updated with bucket name and KMS ARN.

**Manual Steps** (if script fails - The DIY Way):
```bash
# If the script doesn't work, you can do it manually:
# 1. Create S3 bucket (the filing cabinet)
aws s3 mb s3://payflow-terraform-state-$(date +%s) --region us-east-1

# 2. Enable versioning (keep history of changes)
aws s3api put-bucket-versioning \
  --bucket YOUR_BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 3. Create KMS key (the lock)
aws kms create-key --description "PayFlow Terraform State Encryption Key"

# 4. Create DynamoDB table (prevents two people editing at once)
aws dynamodb create-table \
  --table-name payflow-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## Step 2: Deploy Hub Infrastructure (Building the Foundation)

**The Story**: Now you're ready to build! This step creates:
- The network (like building roads and utilities)
- The shared services (like the library, post office, and security gate)
- Everything that Production and Development will need

```bash
cd terraform/environments/hub

# Copy example variables (if not exists)
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Think of this as filling out a building permit form:
# Required:
# - bastion_key_pair_name: "payflow-bastion"  # The name of your security key
# - terraform_state_bucket: "payflow-terraform-state-xxxxx"  # From Step 1
# 
# ✨ Magic: IP Auto-Detection! ✨
# - bastion_allowed_cidrs: []  # Leave empty - Terraform automatically detects your IP!
#   No need to run `curl ifconfig.me` - Terraform does it for you!
#   OR provide manually if needed: bastion_allowed_cidrs = ["YOUR_IP/32"]

# Initialize Terraform (like loading your toolbox)
terraform init -backend-config=backend-config.hcl

# Review plan (like reviewing the blueprint before building)
terraform plan
# This shows you EXACTLY what will be created. Review it carefully!

# Apply changes (actually building - takes ~15-20 minutes)
terraform apply
# Say "yes" when prompted. Then grab a coffee - this takes a while! ☕
```

**What Gets Created** (The Construction Checklist):

**Networking** (The Roads):
- VPC with public/private subnets (3 availability zones - like 3 different neighborhoods for redundancy)
- NAT Gateways (3x for Multi-AZ - like toll booths connecting to the internet)
- VPC Endpoints (private highways to AWS services - saves money!)

**Compute** (The Buildings):
- EKS cluster (private endpoint only - secure!)
- EKS node group (2x t3.small servers - the workers)
- Bastion host (t3.micro - the security gate)

**Storage & Services**:
- ECR repositories (for all services - like a warehouse)
- S3 backend bucket (for Terraform state - the filing cabinet)
- DynamoDB locking table (prevents conflicts)
- KMS key (for encryption - the lock)

**Expected Output** (Success Looks Like This):
```
Apply complete! Resources: 45 added, 0 changed, 0 destroyed.

Outputs:
bastion_public_ip = "54.123.45.67"  ← The address of your security gate
bastion_allowed_ip = "Auto-detected: 203.0.113.1/32"  ← Your IP (auto-detected!)
eks_cluster_id = "payflow-hub-eks"  ← Your Kubernetes cluster name
terraform_state_bucket = "payflow-terraform-state-xxxxx"  ← Your filing cabinet
vpc_id = "vpc-xxxxx"  ← Your network ID
```

**✨ Magic Moment**: Notice `bastion_allowed_ip` shows your auto-detected IP! Terraform automatically fetched your public IP and configured it. No manual `curl ifconfig.me` needed!

**🎉 Congratulations!** You've built the foundation! Now let's connect to it.

---

## Step 3: Configure kubectl Access (Getting Your Access Card)

**The Story**: You've built the secure building (EKS cluster), but you need an access card (kubectl config) to get in. The bastion host is like the security guard who gives you the card.

**What We're Doing**: Setting up kubectl so you can talk to your Kubernetes cluster. Think of kubectl as a remote control for your applications.

```bash
# Get bastion IP from Terraform output
# This is like getting the security guard's phone number
BASTION_IP=$(terraform output -raw bastion_public_ip)

# SSH to bastion
# Like calling the security guard and asking for access
ssh -i payflow-bastion.pem ec2-user@${BASTION_IP}

# On bastion, configure kubectl
# Like getting your access card programmed
aws eks update-kubeconfig \
  --region us-east-1 \
  --name payflow-hub-eks

# Verify cluster access
# Like testing your access card works
kubectl get nodes
```

**Expected Output** (Your Access Card Works!):
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-10-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
ip-10-0-11-xxx.ec2.internal   Ready    <none>   5m    v1.28.x
```

**What This Means**: 
- ✅ Your cluster is running
- ✅ You have 2 worker nodes ready
- ✅ You can now deploy applications!

---

## Step 4: Verify Hub Deployment (The Quality Check)

**The Story**: Before celebrating, let's make sure everything was built correctly. We'll check each major component like a building inspector.

```bash
# Check EKS cluster (the main building)
aws eks describe-cluster --name payflow-hub-eks
# Should show status: ACTIVE ✅

# Check VPC endpoints (the private highways)
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
# Should show 4 endpoints with status: available ✅

# Check ECR repositories (the warehouse)
aws ecr describe-repositories \
  --query 'repositories[*].repositoryName'
# Should show 6 repositories (one for each service) ✅

# Check bastion (the security gate)
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=payflow-bastion"
# Should show instance state: running ✅
```

**Success Criteria** (The Inspection Checklist):
- ✅ EKS cluster status: ACTIVE (the building is operational)
- ✅ All VPC endpoints status: available (the highways are open)
- ✅ ECR repositories exist (6 services) (the warehouse has space)
- ✅ Bastion host running (the security gate is staffed)
- ✅ kubectl can access cluster (your access card works)

**🎉 If all checks pass, you've successfully built the Hub!**

---

## ⚠️ Troubleshooting (When Things Go Wrong)

### Error: "Bucket already exists"

**The Problem**: Someone (or you) already created a bucket with that name.

**The Solution**: 
- Choose a unique bucket name in `terraform.tfvars`
- Or use the bucket created by `init-backend.sh` script
- Bucket names must be globally unique across all AWS accounts

**Analogy**: Like trying to name your building the same as another building in the world.

---

### Error: "Insufficient permissions"

**The Problem**: Your AWS user doesn't have permission to create resources.

**The Solution**: Your AWS user needs these IAM permissions:
- EC2:FullAccess (to create VPCs, instances, etc.)
- EKS:FullAccess (to create Kubernetes clusters)
- IAM:CreateRole, IAM:AttachRolePolicy (to create roles)
- S3:FullAccess (to create buckets)
- DynamoDB:FullAccess (to create locking table)
- KMS:FullAccess (to create encryption keys)

**How to Fix**: Contact your AWS administrator or add these permissions to your IAM user/role.

**Analogy**: Like trying to build without a construction permit.

---

### Error: "VPC doesn't have sufficient IP addresses"

**The Problem**: Your network doesn't have enough IP addresses for EKS.

**The Solution**: 
- Check subnet CIDR blocks are /24 or larger
- EKS needs at least 256 IPs per subnet
- The VPC should use /16 CIDR (65,536 IPs)

**Analogy**: Like trying to build a 1000-unit apartment building in a neighborhood with only 10 addresses.

---

### Error: "Cannot SSH to bastion"

**The Problem**: Your security group doesn't allow SSH from your IP address.

**The Solution**:
1. Get your current IP: `curl ifconfig.me`
2. Update security group: Add your IP to `bastion_allowed_cidrs` in `terraform.tfvars`
3. Re-apply: `terraform apply`

**Analogy**: Like trying to enter a building where security doesn't recognize you.

**Pro Tip**: If your IP changes frequently (like home internet), consider using a VPN or checking your IP each time before SSH.

---

## 🎉 What's Next?

You've successfully built the foundation! The Hub is now:
- ✅ Running and accessible
- ✅ Ready for Production and Development to connect
- ✅ Secure (private endpoints, bastion access)
- ✅ Cost-optimized (VPC endpoints saving money)

**Ready to build the Production environment?** → [Next: Deploy Production](./04-DEPLOY-PRODUCTION.md)
