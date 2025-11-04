# ============================================
# PayFlow EKS Cluster Module
# ============================================
# Purpose: Reusable EKS cluster module for Hub and Spoke environments
# Security: Private endpoint only, access via bastion host
# Cost: $72/month (control plane) + node costs
#
# Why EKS:
# - Managed Kubernetes (AWS handles control plane updates)
# - Integrated with AWS services (IAM, VPC, CloudWatch)
# - Production-ready with HA built-in

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ============================================
# EKS Cluster: Kubernetes Control Plane
# ============================================
# Purpose: Managed Kubernetes cluster
# Cost: $72/month (fixed, regardless of usage)
# Security: Private endpoint only, no public access

resource "aws_eks_cluster" "payflow" {
  name     = "${var.project_name}-${var.environment}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  # Network configuration: Private subnets only
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true  # SECURE: Private endpoint only
    endpoint_public_access  = false # SECURE: No public access
    # Note: EKS creates its own security group automatically
    # We add ingress rules to the cluster's default security group below
  }

  # Encryption: Encrypt secrets at rest
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  # Enable logging for troubleshooting
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-eks"
  })
}

# CloudWatch Log Group: Cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.project_name}-${var.environment}-eks/cluster"
  retention_in_days = 7 # Cost optimization: 7 days retention

  tags = var.tags
}

# ============================================
# IAM Role: EKS Cluster Service Role
# ============================================
# Purpose: EKS control plane needs permissions to manage AWS resources

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ============================================
# EKS Node Group: Worker Nodes
# ============================================
# Purpose: Run your application pods
# Cost: Depends on instance type and count
# Strategy: Different instance types per environment (dev vs prod)

resource "aws_eks_node_group" "payflow" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.payflow.name
  node_group_name = "${var.project_name}-${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids

  # Instance configuration
  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type # ON_DEMAND or SPOT
  disk_size      = each.value.disk_size

  # Scaling configuration
  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  # Update configuration
  update_config {
    max_unavailable = 1 # Allow rolling updates
  }

  # Remote access: Only from bastion security group
  remote_access {
    ec2_ssh_key               = var.node_key_pair_name
    source_security_group_ids = [var.bastion_security_group_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  })
}

# ============================================
# IAM Role: EKS Node Group
# ============================================
# Purpose: Worker nodes need permissions to pull images, write logs, etc.

resource "aws_iam_role" "nodes" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# ============================================
# Security Group Rules: Bastion to EKS API Access
# ============================================
# Purpose: Allow bastion host to access EKS API endpoint (port 443)
# Why: EKS cluster has private endpoint only, bastion provides secure access path
# Security: Only bastion security group can access EKS API

resource "aws_security_group_rule" "bastion_to_eks_api" {
  count = var.bastion_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.bastion_security_group_id
  security_group_id        = aws_eks_cluster.payflow.vpc_config[0].cluster_security_group_id
  description              = "HTTPS access from bastion host to EKS API"
}


