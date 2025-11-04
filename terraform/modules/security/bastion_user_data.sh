#!/bin/bash
# ============================================
# Enhanced Bastion Host User Data Script
# ============================================
# Purpose: Complete EKS access setup with error handling and logging
# Security: No hardcoded secrets, uses IAM roles and AWS services

set -e
exec > >(tee /var/log/bastion-setup.log) 2>&1

echo "=== Starting Enhanced Bastion Setup at $(date) ==="

# Update system packages
echo "Updating system packages..."
yum update -y

# Install kubectl (latest stable)
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
kubectl version --client || echo "kubectl installed, version check will work after cluster access"

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
/usr/local/bin/aws --version

# Install eksctl
echo "Installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
eksctl version

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Install additional tools
echo "Installing additional tools..."
yum install -y jq git htop tree wget curl unzip

# Setup kubectl config directory with proper permissions
echo "Setting up kubectl configuration..."
mkdir -p /home/ec2-user/.kube
chown ec2-user:ec2-user /home/ec2-user/.kube
chmod 755 /home/ec2-user/.kube

# Get region and account info from metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

echo "AWS Region: $REGION"
echo "Account ID: $ACCOUNT_ID"

# Create comprehensive EKS helper script
echo "Creating EKS connection helper script..."
cat > /home/ec2-user/eks-helper.sh << 'EOF'
#!/bin/bash
# ============================================
# PayFlow EKS Management Helper Script
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get AWS metadata
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")

echo -e "${GREEN}=== PayFlow EKS Management Helper ===${NC}"
echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo ""

# List available EKS clusters
list_clusters() {
    echo -e "${BLUE}Available EKS clusters:${NC}"
    aws eks list-clusters --region $REGION --output table || {
        echo -e "${RED}Failed to list clusters. Check AWS credentials and permissions.${NC}"
        return 1
    }
}

# Connect to specific cluster
connect_cluster() {
    local cluster_name=$1
    if [ -z "$cluster_name" ]; then
        echo -e "${RED}Usage: connect_cluster <cluster-name>${NC}"
        echo "Example: connect_cluster payflow-hub-eks"
        return 1
    fi
    
    echo -e "${YELLOW}Configuring kubectl for cluster: $cluster_name${NC}"
    
    # Update kubeconfig
    if aws eks update-kubeconfig --region $REGION --name $cluster_name; then
        echo -e "${GREEN}✓ Successfully configured kubectl${NC}"
        
        # Test connection
        echo -e "${YELLOW}Testing connection...${NC}"
        if kubectl cluster-info; then
            echo -e "${GREEN}✓ Cluster connection successful${NC}"
            
            # Show cluster status
            echo -e "\n${BLUE}Cluster Status:${NC}"
            kubectl get nodes
            echo -e "\n${BLUE}System Pods:${NC}"
            kubectl get pods -n kube-system
            
        else
            echo -e "${RED}✗ Failed to connect to cluster${NC}"
            echo "Check:"
            echo "1. Cluster exists and is active"
            echo "2. Security group allows bastion → EKS API (port 443)"
            echo "3. IAM permissions for EKS access"
        fi
    else
        echo -e "${RED}✗ Failed to configure kubectl${NC}"
        return 1
    fi
}

# Auto-discover and show PayFlow clusters
discover_payflow_clusters() {
    echo -e "${BLUE}Discovering PayFlow clusters...${NC}"
    
    local found_clusters=()
    for env in hub production development; do
        local cluster_name="payflow-${env}-eks"
        if aws eks describe-cluster --name $cluster_name --region $REGION >/dev/null 2>&1; then
            found_clusters+=($cluster_name)
            echo -e "${GREEN}✓ Found: $cluster_name${NC}"
        fi
    done
    
    if [ ${#found_clusters[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}To connect to a cluster, use:${NC}"
        for cluster in "${found_clusters[@]}"; do
            echo "  connect_cluster $cluster"
        done
    else
        echo -e "${YELLOW}No PayFlow clusters found. Make sure they are deployed.${NC}"
    fi
}

# Show cluster logs
show_logs() {
    local namespace=${1:-default}
    echo -e "${BLUE}Recent logs from namespace: $namespace${NC}"
    kubectl logs --tail=50 -l app.kubernetes.io/name --namespace=$namespace
}

# Port forward helper
port_forward() {
    local service=$1
    local port=${2:-8080}
    local namespace=${3:-default}
    
    if [ -z "$service" ]; then
        echo -e "${RED}Usage: port_forward <service> [port] [namespace]${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Port forwarding $service:$port in namespace $namespace${NC}"
    kubectl port-forward service/$service $port:$port -n $namespace
}

# Show helper menu
show_help() {
    echo -e "${GREEN}Available commands:${NC}"
    echo "  list_clusters                    - List all EKS clusters"
    echo "  connect_cluster <name>           - Connect to specific cluster"
    echo "  discover_payflow_clusters        - Find PayFlow clusters"
    echo "  show_logs [namespace]            - Show recent logs"
    echo "  port_forward <service> [port] [ns] - Port forward to service"
    echo "  k                                - kubectl alias"
    echo "  kgp                              - kubectl get pods"
    echo "  kgs                              - kubectl get services"
    echo "  kgn                              - kubectl get nodes"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  connect_cluster payflow-hub-eks"
    echo "  show_logs kube-system"
    echo "  port_forward grafana 3000 monitoring"
}

# Export functions
export -f list_clusters connect_cluster discover_payflow_clusters show_logs port_forward show_help

# Auto-run discovery on script load
discover_payflow_clusters
echo ""
echo -e "${YELLOW}Type 'show_help' for available commands${NC}"
EOF

chmod +x /home/ec2-user/eks-helper.sh
chown ec2-user:ec2-user /home/ec2-user/eks-helper.sh

# Create secrets manager helper script
echo "Creating secrets manager helper script..."
cat > /home/ec2-user/secrets-helper.sh << 'EOF'
#!/bin/bash
# ============================================
# PayFlow Secrets Management Helper
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get region
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo -e "${GREEN}=== PayFlow Secrets Manager Helper ===${NC}"

# List all secrets
list_secrets() {
    echo -e "${BLUE}PayFlow Secrets:${NC}"
    aws secretsmanager list-secrets --region $REGION \
        --query 'SecretList[?contains(Name, `payflow`)].{Name:Name,Description:Description}' \
        --output table
}

# Get secret value
get_secret() {
    local secret_name=$1
    if [ -z "$secret_name" ]; then
        echo -e "${RED}Usage: get_secret <secret-name>${NC}"
        echo "Use list_secrets to see available secrets"
        return 1
    fi
    
    echo -e "${YELLOW}Retrieving secret: $secret_name${NC}"
    aws secretsmanager get-secret-value --secret-id $secret_name --region $REGION \
        --query 'SecretString' --output text | jq '.' || {
        echo -e "${RED}Failed to retrieve secret${NC}"
        return 1
    }
}

# Create Kubernetes secret from AWS Secrets Manager
create_k8s_secret() {
    local aws_secret_name=$1
    local k8s_secret_name=$2
    local namespace=${3:-default}
    
    if [ -z "$aws_secret_name" ] || [ -z "$k8s_secret_name" ]; then
        echo -e "${RED}Usage: create_k8s_secret <aws-secret-name> <k8s-secret-name> [namespace]${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Creating Kubernetes secret $k8s_secret_name from $aws_secret_name${NC}"
    
    # Get secret value
    local secret_value=$(aws secretsmanager get-secret-value --secret-id $aws_secret_name --region $REGION --query 'SecretString' --output text)
    
    if [ $? -eq 0 ]; then
        # Create Kubernetes secret
        echo "$secret_value" | kubectl create secret generic $k8s_secret_name \
            --from-file=config=/dev/stdin \
            --namespace=$namespace
        echo -e "${GREEN}✓ Kubernetes secret created successfully${NC}"
    else
        echo -e "${RED}✗ Failed to retrieve AWS secret${NC}"
        return 1
    fi
}

# Export functions
export -f list_secrets get_secret create_k8s_secret

echo -e "${YELLOW}Available commands:${NC}"
echo "  list_secrets                     - List PayFlow secrets"
echo "  get_secret <name>                - Get secret value"
echo "  create_k8s_secret <aws> <k8s> [ns] - Create K8s secret from AWS"
EOF

chmod +x /home/ec2-user/secrets-helper.sh
chown ec2-user:ec2-user /home/ec2-user/secrets-helper.sh

# Enhanced bashrc with all helpers
echo "Configuring enhanced bashrc..."
cat >> /home/ec2-user/.bashrc << 'EOF'

# ============================================
# PayFlow Bastion Host Environment
# ============================================

# Load helpers
source ~/eks-helper.sh
source ~/secrets-helper.sh

# Kubernetes aliases
alias k=kubectl
alias kgp="kubectl get pods"
alias kgs="kubectl get services"
alias kgn="kubectl get nodes"
alias kgd="kubectl get deployments"
alias kdp="kubectl describe pod"
alias kds="kubectl describe service"
alias kdn="kubectl describe node"
alias klogs="kubectl logs -f"
alias kexec="kubectl exec -it"

# AWS aliases  
alias awsp="aws sts get-caller-identity"
alias awsr="aws configure get region"

# Useful functions
function kns() {
    kubectl config set-context --current --namespace=$1
    echo "Switched to namespace: $1"
}

function kwatch() {
    watch -n 2 kubectl get pods
}

# Enhanced prompt
export PS1='\[\033[01;32m\]payflow-bastion\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Welcome message
echo ""
echo -e "\033[1;32m=== PayFlow Bastion Host ===\033[0m"
echo "EKS Management Terminal"
echo ""
echo -e "\033[1;33mQuick Start:\033[0m"
echo "  show_help           - Show EKS commands"
echo "  list_secrets        - Show secrets"
echo "  connect_cluster payflow-hub-eks"
echo ""
EOF

chown ec2-user:ec2-user /home/ec2-user/.bashrc

# Create monitoring script
echo "Creating monitoring script..."
cat > /home/ec2-user/monitor.sh << 'EOF'
#!/bin/bash
# System monitoring for bastion host

echo "=== PayFlow Bastion Monitor ==="
echo "Date: $(date)"
echo ""

echo "=== System Resources ==="
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "Disk: $(df -h / | grep '/' | awk '{print $3 "/" $2 " (" $5 ")"}')"
echo ""

echo "=== Network Connectivity ==="
# Test AWS API
if curl -s --max-time 5 https://sts.amazonaws.com > /dev/null; then
    echo "✓ AWS API: Connected"
else
    echo "✗ AWS API: Failed"
fi

# Test EKS if configured
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✓ EKS: Connected"
else
    echo "✗ EKS: Not connected"
fi

echo ""
echo "=== Recent Logs ==="
tail -5 /var/log/bastion-setup.log
EOF

chmod +x /home/ec2-user/monitor.sh
chown ec2-user:ec2-user /home/ec2-user/monitor.sh

# Set up log rotation
echo "Setting up log rotation..."
cat > /etc/logrotate.d/bastion-logs << 'EOF'
/var/log/bastion-*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 644 root root
}
EOF

# Final setup
echo "Finalizing setup..."
# Update locate database
updatedb 2>/dev/null || true

# Create completion marker
touch /var/log/bastion-setup-complete
echo "$(date): Bastion setup completed successfully" >> /var/log/bastion-setup-complete

echo "=== Enhanced Bastion Setup Complete at $(date) ==="
echo ""
echo "✓ Tools installed: kubectl, aws-cli, eksctl, helm, jq"
echo "✓ Helper scripts created:"
echo "  - ~/eks-helper.sh (EKS management)"
echo "  - ~/secrets-helper.sh (Secrets Manager)"  
echo "  - ~/monitor.sh (System monitoring)"
echo ""
echo "✓ Enhanced aliases and functions configured"
echo "✓ Log rotation configured"
echo ""
echo "Next steps:"
echo "1. SSH to bastion: ssh -i ~/.ssh/payflow-bastion.pem ec2-user@<BASTION_IP>"
echo "2. Run: connect_cluster payflow-hub-eks"
echo "3. Verify: kubectl get nodes"