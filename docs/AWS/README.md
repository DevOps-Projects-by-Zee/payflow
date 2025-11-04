# AWS Deployment - PayFlow FinTech Platform

**Production-grade fintech platform for learning DevOps**

## 🎯 Quick Overview

**Cost:** $180-250/month | **Time:** 3 hours | **Difficulty:** Intermediate

## 📚 Learning Path

**New to AWS? Follow this numbered path:**

1. **[00-START-HERE.md](./00-START-HERE.md)** (5 min) - Overview and quick start
2. **[01-PREREQUISITES.md](./01-PREREQUISITES.md)** (30 min) - Setup tools and AWS account
3. **[02-UNDERSTAND-FIRST.md](./02-UNDERSTAND-FIRST.md)** (30 min) - **Read BEFORE deploying** - Learn hub-spoke architecture
4. **[03-DEPLOY-HUB.md](./03-DEPLOY-HUB.md)** (45 min) - Deploy shared services
5. **[04-DEPLOY-PRODUCTION.md](./04-DEPLOY-PRODUCTION.md)** (30 min) - Deploy production environment
6. **[05-DEPLOY-DEVELOPMENT.md](./05-DEPLOY-DEVELOPMENT.md)** (20 min) - Deploy development environment
7. **[99-REFERENCE.md](./99-REFERENCE.md)** - Troubleshooting, cost breakdown, interview prep

**Already know AWS?** Start with [00-START-HERE.md](./00-START-HERE.md) and jump to deployment guides, but still read [02-UNDERSTAND-FIRST.md](./02-UNDERSTAND-FIRST.md).

## 🚀 Quick Commands (If You've Done This Before)

```bash
# 1. Initialize backend
scripts/terraform/init-backend.sh

# 2. Deploy Hub
cd terraform/environments/hub
terraform init -backend-config=backend-config.hcl
terraform apply

# 3. Deploy Production
cd ../production
terraform init -backend-config=backend-config.hcl
terraform apply

# 4. Deploy Development
cd ../development
terraform init -backend-config=backend-config.hcl
terraform apply
```

## 💰 Cost Breakdown

| Environment | Cost |
|------------|------|
| Hub | ~$175/month |
| Production | ~$305/month |
| Development | ~$50/month |
| **Total** | **~$530/month** |

*Development can scale to zero when not in use (save $72/month)*

**See [Cost Optimization](../COST-OPTIMIZATION.md) for detailed cost breakdown and optimization strategies.**

---

**Ready to start?** → [Start Here](./00-START-HERE.md)
