# Amazon MQ (RabbitMQ) Module for PayFlow
# Purpose: Managed message queue service (replaces K8s RabbitMQ)
# Cost: ~$15/month (mq.t3.micro, single AZ) - cost-effective for fintech startup
# Security: Private subnet, no public access

# Amazon MQ Broker (RabbitMQ)
resource "aws_mq_broker" "main" {
  broker_name = var.broker_name
  engine_type = "RabbitMQ"
  
  # Use RabbitMQ 3.11.20 (matches current app version)
  engine_version = "3.11.20"
  
  # Cost-effective: Single AZ for development, Multi-AZ for production
  # Single AZ: ~$15/month, Multi-AZ: ~$30/month
  host_instance_type = var.host_instance_type # mq.t3.micro for cost savings
  deployment_mode    = var.deployment_mode    # SINGLE_INSTANCE or ACTIVE_STANDBY_MULTI_AZ
  
  # Security: Private subnet only, no public access
  publicly_accessible = false
  subnet_ids          = var.subnet_ids
  
  # Authentication
  user {
    username = var.username
    password = var.password
  }
  
  # Security groups
  security_groups = var.security_group_ids
  
  # Logging
  logs {
    general = var.enable_general_logs
    audit   = var.enable_audit_logs
  }
  
  # Maintenance window
  maintenance_window_start_time {
    day_of_week = "MONDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }
  
  tags = var.tags
}

# CloudWatch Log Group for MQ logs
resource "aws_cloudwatch_log_group" "mq" {
  count             = var.enable_general_logs ? 1 : 0
  name              = "/aws/amazonmq/${var.broker_name}"
  retention_in_days = 7 # Keep logs for 1 week (cost optimization)

  tags = var.tags
}

