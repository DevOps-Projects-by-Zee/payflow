# Troubleshooting Guide - PayFlow Deployment Issues

**Complete troubleshooting reference for common deployment and operational issues**

## 🔧 Common Issues

### Terraform Backend Initialization Fails

**Error**:
```
Error: Failed to get existing workspaces
Error: NoSuchBucket: The specified bucket does not exist
```

**Solution**:
1. Run: `scripts/terraform/init-backend.sh`
2. Verify `backend-config.hcl` has correct bucket name
3. Re-initialize: `terraform init -backend-config=backend-config.hcl`

**Check if bucket exists**:
```bash
aws s3 ls | grep payflow-terraform-state
```

**Verify backend-config.hcl**:
```bash
cat terraform/environments/hub/backend-config.hcl
# Should have actual bucket name, not "xxxxx"
```

### EKS Cluster Creation Fails

**Error**:
```
Error: VPC doesn't have sufficient IP addresses
```

**Solution**:
1. Check subnet CIDR blocks are /24 or larger
2. EKS needs at least 256 IPs per subnet
3. Verify VPC CIDR is /16 (65,536 IPs)

**Check VPC CIDR**:
```bash
aws ec2 describe-vpcs --vpc-ids vpc-xxxxx
# Should show /16 CIDR block
```

**Check subnet sizes**:
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"
# Should show /24 or larger subnets
```

### Cannot SSH to Bastion

**Error**:
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Solution**:
1. Check security group allows SSH from your IP
2. Get your IP: `curl ifconfig.me`
3. Update security group: `bastion_allowed_cidrs` in `terraform.tfvars`
4. Re-apply: `terraform apply`

**Verify security group rules**:
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=payflow-bastion" \
  --query 'SecurityGroups[0].IpPermissions'
```

### External Secrets Not Syncing

**Error**:
```
Status: Error or NotReady
```

**Solution**:
1. Check ESO is installed: `kubectl get pods -n external-secrets-system`
2. Verify IAM role has Secrets Manager permissions
3. Check secret ARNs are correct in `external-secrets.yaml`
4. Review ESO logs: `kubectl logs -n external-secrets-system deployment/external-secrets-operator`

**Check ESO installation**:
```bash
kubectl get pods -n external-secrets-system
# Should show Running status
```

**Verify IAM role**:
```bash
kubectl get serviceaccount -n payflow external-secrets -o yaml
# Should have annotation with IAM role ARN
```

### RDS Connection Fails

**Error**:
```
Error: connect ECONNREFUSED
```

**Solution**:
1. Check security group allows PostgreSQL port (5432) from EKS security group
2. Verify VPC peering is active
3. Check route tables have peering routes

**Test connection from pod**:
```bash
kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -- sh
# Inside pod: psql -h payflow-production-postgres.xxxxx.rds.amazonaws.com -U payflow
```

**Verify VPC peering**:
```bash
aws ec2 describe-vpc-peering-connections \
  --filters "Name=status-code,Values=active"
```

### Pod Cannot Pull Images from ECR

**Error**:
```
Error: ImagePullBackOff
Error: unauthorized: authentication required
```

**Solution**:
1. Login to ECR: `aws ecr get-login-password --region us-east-1 | docker login ...`
2. Verify EKS node role has ECR read permissions
3. Check VPC endpoints for ECR are configured

**Check ECR access from node**:
```bash
# SSH to EKS node (via bastion)
# Test ECR login
aws ecr get-login-password --region us-east-1
```

**Verify VPC endpoints**:
```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'VpcEndpoints[?ServiceName==`com.amazonaws.us-east-1.ecr.api`]'
```

### Terraform State Locked

**Error**:
```
Error: Error acquiring the state lock
```

**Solution**:
1. Check if another Terraform process is running
2. If sure no one else is running: `terraform force-unlock LOCK_ID`
3. Or wait 10 minutes for lock to expire

**Find lock ID**:
```bash
aws dynamodb scan \
  --table-name payflow-terraform-locks \
  --query 'Items[0].LockID.S'
```

### VPC Peering Connection Failed

**Error**:
```
Error: vpc peering connection is not active
```

**Solution**:
1. Accept peering connection (if cross-account)
2. Verify route tables have peering routes
3. Check security groups allow peering traffic

**Check peering status**:
```bash
aws ec2 describe-vpc-peering-connections \
  --vpc-peering-connection-ids pcx-xxxxx
```

**Verify route tables**:
```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-xxxxx" \
  --query 'RouteTables[*].Routes'
```

### Cost Higher Than Expected

**Problem**: AWS bill shows $800/month instead of $530/month

**Solution**:
1. Check NAT Gateway count (dev should have 1, production should have 3)
2. Review data transfer costs in Cost Explorer
3. Check CloudWatch logs retention (should be 7 days)
4. Verify Spot instances are being used in dev

**Check NAT Gateway count**:
```bash
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].[NatGatewayId,VpcId]'
```

**Check Cost Explorer**:
1. AWS Console → Cost Explorer
2. Filter by tag: `Environment`
3. Review data transfer costs

## 🔍 Diagnostic Commands

### Check Infrastructure Health

**All EKS clusters**:
```bash
aws eks list-clusters
```

**All RDS instances**:
```bash
aws rds describe-db-instances
```

**All VPCs**:
```bash
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=payflow"
```

**All security groups**:
```bash
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=payflow"
```

**All NAT Gateways**:
```bash
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

### Check Kubernetes Health

**All pods**:
```bash
kubectl get pods -A
```

**Pod logs**:
```bash
kubectl logs -f deployment/api-gateway -n payflow
```

**External Secrets status**:
```bash
kubectl get externalsecrets -n payflow
```

**Secret contents**:
```bash
kubectl get secret db-secrets -n payflow -o yaml
```

**Node status**:
```bash
kubectl get nodes
kubectl describe node <node-name>
```

### Check Network Connectivity

**Test from pod to RDS**:
```bash
kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -- sh
# Inside pod:
psql -h payflow-production-postgres.xxxxx.rds.amazonaws.com -U payflow
```

**Test from pod to Redis**:
```bash
kubectl run -it --rm debug --image=redis:7-alpine --restart=Never -- sh
# Inside pod:
redis-cli -h payflow-production-redis.xxxxx.cache.amazonaws.com
```

**Test from pod to another service**:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
# Inside pod:
curl http://api-gateway.payflow.svc.cluster.local:3000/health
```

## 🚨 Emergency Procedures

### Terraform State Corruption

**If state is corrupted or lost**:
1. Check S3 bucket for state file versions
2. Restore from previous version in S3
3. Or import existing resources if state completely lost

**Restore from S3 version**:
```bash
aws s3api list-object-versions \
  --bucket payflow-terraform-state-xxxxx \
  --prefix hub/terraform.tfstate
```

### EKS Cluster Not Accessible

**If you can't access EKS cluster**:
1. Verify bastion host is running
2. Check security group allows bastion → EKS API
3. Verify kubectl config is correct
4. Check EKS cluster status in AWS Console

**Reconfigure kubectl**:
```bash
# From bastion host
aws eks update-kubeconfig \
  --region us-east-1 \
  --name payflow-hub-eks
```

### High Cost Alert

**If costs spike unexpectedly**:
1. Check Cost Explorer for unexpected resources
2. Verify no accidental scale-up occurred
3. Check data transfer costs
4. Review CloudWatch logs retention
5. Verify no extra instances were created

**Quick cost check**:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 📚 Related Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Cost Optimization](docs/COST-OPTIMIZATION.md)
- [AWS Deployment Guide](docs/AWS/00-START-HERE.md)

---

**Back to**: [README.md](../README.md) | [AWS Deployment](docs/AWS/00-START-HERE.md)

