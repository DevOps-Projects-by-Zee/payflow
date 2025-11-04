# Cost Optimization - PayFlow AWS Infrastructure

**Complete cost breakdown and optimization strategies**

## 💰 Monthly Costs

### Summary

| Environment | Cost | Breakdown |
|------------|------|-----------|
| **Hub** | ~$175/month | Shared services, EKS, Bastion |
| **Production** | ~$305/month | Multi-AZ HA, On-Demand instances |
| **Development** | ~$50/month | Single-AZ, Spot instances |
| **Total** | **~$530/month** | All environments |

**With Dev Scaled to Zero**: ~$458/month

## 📊 Detailed Cost Breakdown

### Hub Costs (~$175/month)

| Service | Cost | Details |
|---------|------|---------|
| EKS Control Plane | $72/month | Fixed cost |
| EKS Nodes (2x t3.small) | $30/month | $15/month per node |
| NAT Gateway (3x) | $96/month | $32/month per gateway |
| VPC Endpoints | $28/month | 4 endpoints × 3 AZs × $7/AZ |
| Bastion (t3.micro) | $7/month | Secure access point |
| ECR Storage | FREE | First 500MB free |
| S3 Backend | ~$1/month | Very small state files |
| DynamoDB Locks | ~$0.25/month | Pay-per-request |

**After VPC Endpoints Savings**: ~$175/month (endpoints reduce NAT Gateway traffic)

### Production Costs (~$305/month)

| Service | Cost | Details |
|---------|------|---------|
| EKS Control Plane | $72/month | Fixed cost |
| EKS Nodes (3x t3.medium) | $60/month | $20/month per node |
| NAT Gateway (3x Multi-AZ) | $96/month | HA requirement |
| RDS Multi-AZ (db.t3.small) | $60/month | $30/month × 2 (Multi-AZ) |
| Redis Multi-AZ (2 nodes) | $15/month | $7.50/month per node |
| Secrets Manager | ~$2/month | 4 secrets × $0.40/month |

### Development Costs (~$50/month)

| Service | Cost | Details |
|---------|------|---------|
| EKS Control Plane | $72/month | Fixed cost |
| EKS Nodes (1x t3.small Spot) | $7/month | Spot = 50% discount |
| NAT Gateway (1x Single) | $32/month | Single AZ |
| RDS Single-AZ (db.t3.micro) | $15/month | Single AZ |
| Redis Single Node | $7/month | Single node |

**With Scale-to-Zero**: ~$50/month (when not in use, save $72 EKS control plane)

## 🎯 Cost Optimization Strategies

### 1. VPC Endpoints (Saves ~$32/month)

**Strategy**: Route AWS service traffic privately  
**How**: Configure VPC endpoints for S3, ECR, Secrets Manager, CloudWatch Logs  
**Savings**: Avoid NAT Gateway data transfer charges for AWS API calls  
**Trade-off**: None - endpoints are free (gateway) or cheaper than NAT (interface)

### 2. Single NAT Gateway for Dev (Saves $64/month)

**Strategy**: Use single NAT Gateway instead of Multi-AZ  
**How**: Configure development environment with single-AZ networking  
**Savings**: $64/month (2 fewer NAT Gateways)  
**Trade-off**: Less HA (acceptable for dev)

### 3. Spot Instances (Saves 50-70%)

**Strategy**: Use Spot instances for non-critical workloads  
**How**: Configure development EKS node groups with Spot capacity  
**Savings**: 50-70% on compute costs  
**Trade-off**: Can be interrupted (acceptable for dev)

### 4. Scale-to-Zero (Saves $72/month)

**Strategy**: Destroy development environment when not in use  
**How**: Run `terraform destroy` on development environment  
**Savings**: $72/month (EKS control plane) + node costs  
**Trade-off**: Recreation time (~20 minutes) when needed

### 5. Reserved Instances (Future: Saves 30-40%)

**Strategy**: Reserve capacity for 1-year term  
**How**: Purchase Reserved Instances after validating usage patterns  
**Savings**: 30-40% discount on compute  
**When to Use**: After 1 month of stable usage patterns

### 6. Advanced Optimizations

**Graviton Instances** (Saves 20%)
- Use ARM-based Graviton instances (t4g, m6g, c6g)
- **Trade-off**: Need ARM-compatible container images

**Savings Plans** (Saves 20-30%)
- More flexible than Reserved Instances
- Works with variable workloads and multiple instance types

**Auto-Scaling** (Saves Variable)
- Horizontal Pod Autoscaler for pods
- Cluster Autoscaler for nodes
- Scale based on demand patterns

**S3 Intelligent-Tiering** (Saves ~$1/month)
- Automatically moves data to cheaper tiers
- Enable on S3 backend bucket

## 📈 How to Track Costs

### AWS Cost Explorer

1. AWS Console → Cost Explorer
2. Filter by tag: `Environment` (hub, production, development)
3. Set up budgets with alerts

### Cost Allocation Tags

Configure these tags on all resources:
- `Environment`: hub, production, development
- `CostCenter`: shared-services, production-workloads, development
- `Project`: payflow

### Usage

1. Filter by `Environment` tag in Cost Explorer
2. Track spending per environment
3. Set budgets per environment
4. Review spending weekly

### Setting Up Billing Alerts

```bash
# Create SNS topic for billing alerts
aws sns create-topic --name billing-alerts

# Subscribe with your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:billing-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Create CloudWatch alarm for billing
aws cloudwatch put-metric-alarm \
  --alarm-name billing-alert \
  --alarm-description "Alert when AWS charges exceed $50" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 50 \
  --comparison-operator GreaterThanThreshold
```

## 💡 Cost Optimization Decision Matrix

| Strategy | Savings | Complexity | Risk | When to Use |
|----------|---------|------------|------|-------------|
| VPC Endpoints | ~$32/month | Low | None | Always |
| Single NAT (Dev) | $64/month | Low | Medium (HA) | Dev environments |
| Spot Instances | 50-70% | Low | Medium (interruption) | Dev/non-critical |
| Scale-to-Zero | $72/month | Low | Low | When not developing |
| Reserved Instances | 30-40% | Medium | Low | After 1 month usage |
| Graviton | 20% | High | Medium (compatibility) | New deployments |
| Auto-Scaling | Variable | High | Low | Production workloads |

## 🎯 Target Costs by Optimization Level

### Baseline (No Optimization)
- **Total**: ~$530/month

### Basic Optimization
- VPC Endpoints: -$32/month
- Single NAT (Dev): -$64/month
- **Total**: ~$434/month

### Aggressive Optimization
- VPC Endpoints: -$32/month
- Single NAT (Dev): -$64/month
- Spot Instances (Dev): -$15/month
- Scale-to-Zero (Dev): -$72/month (when not in use)
- **Total**: ~$347/month (with dev scaled down)

### Maximum Optimization (After 1 Month)
- All basic optimizations
- Reserved Instances (Production): -$60/month (30% savings)
- Graviton Instances: -$10/month
- **Total**: ~$280/month

## 📚 Related Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [AWS Deployment Guide](docs/AWS/00-START-HERE.md)
- [Troubleshooting - Cost Issues](docs/TROUBLESHOOTING.md#cost-higher-than-expected)

---

**Back to**: [README.md](../README.md) | [AWS Deployment](docs/AWS/00-START-HERE.md)

