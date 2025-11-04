#!/bin/bash
# ============================================
# PayFlow Secure Deployment Script
# ============================================
# Purpose: Deploy complete secure PayFlow infrastructure
# Security: Private EKS, bastion host, encrypted storage, secrets management
# Cost: Optimized for learning (~$200-300/month total)

set -e

# Configuration
PROJECT_NAME="payflow"
AWS_REGION="us-east-1"
LEARNING_MODE="true"
DESTROY_AFTER_DEPLOY="false"  # Set to true for cost-effective learning

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Please install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        error "Terraform not found. Please install: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        warn "kubectl not found. Will install during deployment."
    fi
    
    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Run: aws configure"
    fi
    
    log "✅ Prerequisites check completed"
}

# Create EC2 Key Pair if it doesn't exist
create_key_pair() {
    local key_name="${PROJECT_NAME}-bastion-key"
    
    log "🔑 Checking/creating EC2 key pair..."
    
    if ! aws ec2 describe-key-pairs --key-names "$key_name" &> /dev/null; then
        log "Creating new key pair: $key_name"
        aws ec2 create-key-pair --key-name "$key_name" --query 'KeyMaterial' --output text > "$key_name.pem"
        chmod 400 "$key_name.pem"
        log "✅ Key pair created and saved as $key_name.pem"
        echo "BASTION_KEY_PAIR_NAME=$key_name" >> .env
    else
        log "✅ Key pair $key_name already exists"
        echo "BASTION_KEY_PAIR_NAME=$key_name" >> .env
    fi
}

# Get user's public IP for bastion access
get_user_ip() {
    log "🌐 Getting your public IP for bastion access..."
    
    local user_ip
    user_ip=$(curl -s https://checkip.amazonaws.com)
    
    if [[ -n "$user_ip" ]]; then
        log "✅ Your public IP: $user_ip"
        echo "USER_IP_CIDR=$user_ip/32" >> .env
    else
        warn "Could not detect your IP. Using 0.0.0.0/0 (less secure)"
        echo "USER_IP_CIDR=0.0.0.0/0" >> .env
    fi
}

# Deploy Hub Environment (Security Infrastructure)
deploy_hub() {
    log "🏗️ Deploying Hub Environment (Shared Services + Security)..."
    
    cd terraform/environments/hub
    
    # Copy secure configuration
    cp main-secure.tf main.tf
    cp variables-secure.tf variables.tf
    
    # Load environment variables
    source ../../../.env 2>/dev/null || true
    
    # Initialize Terraform (first time - local backend)
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
project_name = "$PROJECT_NAME"
aws_region = "$AWS_REGION"
learning_mode = $LEARNING_MODE
single_nat_gateway = true
enable_paid_endpoints = false
enable_bastion_host = true
bastion_key_pair_name = "${BASTION_KEY_PAIR_NAME:-}"
bastion_allowed_cidrs = ["${USER_IP_CIDR:-0.0.0.0/0}"]
budget_alert_email = "${BUDGET_EMAIL:-admin@example.com}"
EOF
    
    # Plan and apply
    terraform plan -out=hub.plan
    
    if [[ "$LEARNING_MODE" == "true" ]]; then
        log "📚 Learning Mode: Review the plan above to understand what will be created"
        read -p "Continue with deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled"
            exit 0
        fi
    fi
    
    terraform apply hub.plan
    
    # Get S3 backend configuration for other environments
    terraform output -raw terraform_backend_config > ../backend-config.hcl 2>/dev/null || true
    
    log "✅ Hub environment deployed successfully"
    cd ../../..
}

# Migrate Hub to S3 Backend
migrate_hub_backend() {
    log "📦 Migrating Hub state to S3 backend for security..."
    
    cd terraform/environments/hub
    
    # Update backend configuration in main.tf
    local bucket_name
    bucket_name=$(terraform output -raw terraform_state_bucket_name 2>/dev/null || echo "")
    
    if [[ -n "$bucket_name" ]]; then
        # Update main.tf with S3 backend
        sed -i.bak 's/# backend "s3"/backend "s3"/' main.tf
        
        # Initialize with S3 backend
        terraform init -backend-config=../backend-config.hcl -migrate-state
        
        log "✅ State migrated to secure S3 backend"
    else
        warn "Could not get S3 bucket name. Continuing with local backend."
    fi
    
    cd ../../..
}

# Deploy Production Environment
deploy_production() {
    log "🏭 Deploying Production Environment..."
    
    cd terraform/environments/production
    
    # Initialize with S3 backend
    if [[ -f ../backend-config.hcl ]]; then
        terraform init -backend-config=../backend-config.hcl
    else
        terraform init
    fi
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
project_name = "$PROJECT_NAME"
aws_region = "$AWS_REGION"
hub_region = "$AWS_REGION"
single_nat_gateway = $LEARNING_MODE
enable_deletion_protection = false
kubernetes_version = "1.28"
postgres_instance_class = "db.t3.micro"
redis_node_type = "cache.t3.micro"
postgres_allocated_storage = 20
redis_num_cache_nodes = 1
postgres_backup_retention_days = 7
EOF
    
    terraform plan -out=production.plan
    terraform apply production.plan
    
    log "✅ Production environment deployed successfully"
    cd ../../..
}

# Configure kubectl for private EKS access
configure_kubectl() {
    log "⚙️ Configuring kubectl for secure EKS access..."
    
    # Get bastion instance ID
    local bastion_instance_id
    bastion_instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=${PROJECT_NAME}-hub-bastion" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "")
    
    if [[ "$bastion_instance_id" != "None" && -n "$bastion_instance_id" ]]; then
        log "✅ Bastion host found: $bastion_instance_id"
        
        # Create connection script
        cat > connect-bastion.sh << EOF
#!/bin/bash
# Connect to bastion host for secure EKS access
aws ssm start-session --target $bastion_instance_id
EOF
        chmod +x connect-bastion.sh
        
        log "📝 Created connect-bastion.sh for secure access"
        log "💡 After connecting to bastion, run: aws eks update-kubeconfig --name ${PROJECT_NAME}-hub-eks"
    else
        warn "Bastion host not found. Manual kubectl configuration needed."
    fi
}

# Deploy PayFlow applications to EKS
deploy_applications() {
    log "🚀 Deploying PayFlow applications to EKS..."
    
    # This would typically be done via ArgoCD after bastion access
    log "📝 Applications will be deployed via ArgoCD after accessing through bastion host"
    log "💡 Connect to bastion first, then access ArgoCD at: http://argocd.payflow.aws:8080"
}

# Display cost information
show_cost_info() {
    log "💰 Estimated Monthly Costs:"
    
    cat << EOF

📊 COST BREAKDOWN (Learning Mode):
┌─────────────────────┬──────────────┬─────────────────┐
│ Component           │ Monthly Cost │ Notes           │
├─────────────────────┼──────────────┼─────────────────┤
│ Hub VPC             │ \$45         │ 1 NAT Gateway   │
│ Hub EKS Control     │ \$72         │ Fixed cost      │
│ Hub EKS Nodes       │ \$30         │ 1x t3.small     │
│ Security (ECR+SM)   │ \$10         │ 6 repos + 3 sec │
│ Bastion Host        │ \$6          │ t3.nano         │
│ Production VPC      │ \$45         │ 1 NAT Gateway   │
│ Production EKS      │ \$72         │ Fixed cost      │ 
│ Production Nodes    │ \$45         │ Mixed Spot      │
│ RDS (Micro)         │ \$25         │ db.t3.micro     │
│ Redis (Micro)       │ \$15         │ cache.t3.micro  │
│ Load Balancers      │ \$50         │ 2x ALB          │
│ VPC Peering         │ \$0          │ FREE!           │
├─────────────────────┼──────────────┼─────────────────┤
│ TOTAL               │ \$415/month  │ Learning mode   │
│ DESTROY DAILY COST  │ \$14/day     │ If destroyed    │
└─────────────────────┴──────────────┴─────────────────┘

💡 Cost Optimization Tips:
- Set DESTROY_AFTER_DEPLOY=true for daily learning (\$14/day)
- Use spot instances in production for 70% savings
- Enable Reserved Instances for stable workloads (40% discount)

EOF
}

# Cleanup function for learning mode
cleanup_resources() {
    if [[ "$DESTROY_AFTER_DEPLOY" == "true" ]]; then
        log "🧹 Destroying resources for cost optimization..."
        
        warn "This will destroy ALL PayFlow infrastructure!"
        read -p "Are you sure you want to destroy everything? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Destroy production first
            cd terraform/environments/production
            terraform destroy -auto-approve
            cd ../../../
            
            # Destroy hub
            cd terraform/environments/hub  
            terraform destroy -auto-approve
            cd ../../../
            
            log "✅ All resources destroyed. Total cost saved!"
        fi
    fi
}

# Main deployment flow
main() {
    log "🚀 PayFlow Secure Deployment Starting..."
    
    # Clean up any previous .env file
    rm -f .env
    touch .env
    
    check_prerequisites
    create_key_pair
    get_user_ip
    
    log "📋 Deployment Plan:"
    echo "  1. Deploy Hub VPC with security infrastructure"
    echo "  2. Deploy Production VPC with applications"  
    echo "  3. Configure secure access via bastion host"
    echo "  4. Set up monitoring and GitOps"
    
    deploy_hub
    migrate_hub_backend
    deploy_production
    configure_kubectl
    deploy_applications
    
    show_cost_info
    
    log "🎉 PayFlow deployment completed successfully!"
    
    cat << EOF

🔐 SECURE ACCESS INFORMATION:
───────────────────────────────────────────
• Bastion Host: Use ./connect-bastion.sh
• EKS Clusters: Private access only via bastion
• Monitoring: Access via bastion port forwarding  
• Secrets: Managed in AWS Secrets Manager
• Container Registry: ECR repositories created

📚 NEXT STEPS:
───────────────────────────────────────────
1. Connect to bastion: ./connect-bastion.sh
2. Configure kubectl: aws eks update-kubeconfig --name ${PROJECT_NAME}-hub-eks
3. Access ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:80
4. Deploy apps: kubectl apply -k k8s/

🎯 LEARNING RESOURCES:
───────────────────────────────────────────
• Architecture: docs/AWS_HUB_SPOKE_ARCHITECTURE.md
• Security Guide: docs/AWS_SECURITY_GUIDE.md  
• Cost Optimization: docs/AWS_COST_OPTIMIZATION.md
• Troubleshooting: docs/TROUBLESHOOTING.md

EOF
    
    cleanup_resources
    
    log "🎊 Deployment complete! Happy learning! 🚀"
}

# Handle script interruption
trap 'error "Deployment interrupted"' INT TERM

# Check if running in learning mode
if [[ "$LEARNING_MODE" == "true" ]]; then
    log "📚 Learning Mode Enabled - Educational prompts and cost optimization active"
fi

# Run main deployment
main "$@"
