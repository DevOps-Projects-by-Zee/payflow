# Architecture Overview - PayFlow Hub-and-Spoke Design

**Understanding the infrastructure design and why it was built this way**

## 🏗️ High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / Cloudflare                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Hub VPC (10.0.0.0/16)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Bastion    │  │   ECR Repos  │  │    EKS      │      │
│  │   Host       │  │              │  │  (Monitoring)│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   Secrets    │  │  S3 Backend  │                        │
│  │   Manager    │  │  (State)     │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
         ↓ VPC Peering              ↓ VPC Peering
┌─────────────────────────┐  ┌─────────────────────────┐
│ Production VPC          │  │ Development VPC         │
│ (10.1.0.0/16)           │  │ (10.2.0.0/16)           │
│ ┌──────────────┐        │  │ ┌──────────────┐        │
│ │ EKS Cluster  │        │  │ │ EKS Cluster │        │
│ │ (Multi-AZ)   │        │  │ │ (Single-AZ)  │        │
│ └──────────────┘        │  │ └──────────────┘        │
│ ┌──────────────┐        │  │ ┌──────────────┐        │
│ │ RDS Postgres │        │  │ │ RDS Postgres │        │
│ │ (Multi-AZ)   │        │  │ │ (Single-AZ)  │        │
│ └──────────────┘        │  │ └──────────────┘        │
│ ┌──────────────┐        │  │ ┌──────────────┐        │
│ │ Redis Cache  │        │  │ │ Redis Cache  │        │
│ │ (Multi-AZ)   │        │  │ │ (Single)    │        │
│ └──────────────┘        │  │ └──────────────┘        │
└─────────────────────────┘  └─────────────────────────┘
```

## 🎯 Why Hub-and-Spoke?

### The Problem: Duplicate Infrastructure Costs

**Without hub-and-spoke**, each environment needs:
- Own ECR repositories (~$5/month)
- Own Secrets Manager infrastructure
- Own S3 backend buckets (~$1/month)
- Duplicate NAT Gateways (~$32/month each)

**Cost Impact**: ~$50/month × 3 environments = **$150/month in duplicate infrastructure**

### The Solution: Hub-and-Spoke Pattern

**Hub** (Shared Services - ~$175/month total):
- ECR repositories (all services share one set)
- Secrets Manager (centralized secrets)
- S3 backend bucket (Terraform state)
- Bastion host (single secure access point)
- Monitoring EKS cluster (shared observability)

**Spokes** (Environment-Specific Workloads):
- Production: ~$305/month (Multi-AZ HA)
- Development: ~$50/month (Single-AZ, Spot instances)

**Total Savings**: **~$150/month** by sharing infrastructure

## 📊 Environment Dependencies

### Deployment Order (CRITICAL)

**Must deploy in this order:**

1. **Hub** (must deploy first - creates shared infrastructure)
2. **Production** (depends on Hub for VPC peering and shared services)
3. **Development** (depends on Hub, independent from Production)

**Why this order?** Production and Development need Hub's VPC ID and route tables for VPC peering.

### State Files

**Same S3 bucket**, different keys:
- Hub: `hub/terraform.tfstate`
- Production: `production/terraform.tfstate`
- Development: `development/terraform.tfstate`

**Why Separate State Files?**
- **Isolation**: Changes to one environment don't affect others
- **Safety**: Accidental destroy only affects one environment
- **Collaboration**: Multiple people can work on different environments

**Why Same Bucket?**
- Cost optimization: One bucket instead of three
- Shared infrastructure: One DynamoDB table, one KMS key

## 🌐 VPC Design

### CIDR Blocks (No Conflicts)

- Hub: `10.0.0.0/16` (65,536 IPs)
- Production: `10.1.0.0/16` (65,536 IPs)
- Development: `10.2.0.0/16` (65,536 IPs)

**Why /16?** EKS needs plenty of IP addresses for pods and services. /16 gives us room to grow.

### Why Private EKS?

**Security**: EKS API endpoint is critical security surface. Private endpoints eliminate public internet exposure.

**Cost**: Private endpoints are **FREE** (public endpoints cost money)

**Access**: Via bastion host (SSH tunnel to EKS API)

**How It Works:**
- EKS control plane: Private endpoint only
- Access via bastion: SSH tunnel to EKS API
- Security groups: Only allow bastion access

### VPC Endpoints Strategy

**Why**: Reduce NAT Gateway costs (~$32/month savings)

**How**: Route AWS service traffic privately (S3, ECR, Secrets Manager)

**Cost Breakdown:**
- **Gateway Endpoints** (FREE): S3, DynamoDB
- **Interface Endpoints** (~$7/AZ/month): ECR API, ECR DKR, Secrets Manager, CloudWatch Logs

**Savings**: Without VPC endpoints, all AWS API calls go through NAT Gateway (data transfer charges). With endpoints, traffic stays within VPC (free).

## 💰 Cost Implications

### Production vs Development

**Production** (Multi-AZ, On-Demand):
- **Why**: High availability required for production workloads
- **Cost**: ~$305/month
- **Trade-off**: Higher cost, but production-grade HA (99.99% uptime)

**Development** (Single-AZ, Spot instances):
- **Why**: Cost optimization acceptable for dev
- **Cost**: ~$50/month
- **Trade-off**: Less HA, but 6x cheaper (acceptable for non-production)

### Scale-to-Zero Strategy

**Development can be destroyed when not in use:**
- Saves $72/month (EKS control plane)
- Can recreate in ~20 minutes
- Perfect for personal projects where you're not always developing

## 🔄 Request Flow Example

**User Transfers Money (Production):**

```
1. User → Cloudflare Tunnel → API Gateway
   ↓
2. API Gateway → Auth Service (validate JWT)
   ↓ (reads from AWS Secrets Manager via External Secrets)
3. API Gateway → Transaction Service
   ↓
4. Transaction Service → Wallet Service (check balance)
   ↓ (reads from RDS via private endpoint)
5. Wallet Service → Redis Cache (check cache)
   ↓ (reads from ElastiCache via private endpoint)
6. Transaction Service → RabbitMQ (publish message)
   ↓ (reads credentials from AWS Secrets Manager)
7. Notification Service (consumes from RabbitMQ)
   ↓
8. Transaction Service → RDS (update balance)
   ↓ (reads from RDS via VPC endpoint)
9. User receives confirmation
```

**Key Security Points:**
- ✅ All secrets come from AWS Secrets Manager
- ✅ No secrets in code or config files
- ✅ Traffic stays within VPC (via VPC endpoints)
- ✅ Private connectivity (no public internet exposure)

## 📚 Related Documentation

- [AWS Deployment Guide - Architecture Section](docs/AWS/02-UNDERSTAND-FIRST.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [Deployment Guides](docs/AWS/)

---

**Back to**: [README.md](../README.md) | [AWS Deployment](docs/AWS/00-START-HERE.md)

