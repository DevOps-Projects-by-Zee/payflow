# CloudWatch Alarms and SNS Module for PayFlow
# Purpose: Cost-effective monitoring and alerting for fintech application
# Cost: ~$2/month (SNS + minimal CloudWatch metrics)

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = var.topic_name
  
  # Cost optimization: Use standard SNS (not FIFO)
  # Delivery retry policy
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 20
        maxDelayTarget     = 300
        numRetries         = 3
        numMaxDelayRetries = 0
        numNoDelayRetries  = 0
        numMinDelayRetries = 0
      }
    }
  })

  tags = var.tags
}

# Email Subscription (optional - verify manually)
resource "aws_sns_topic_subscription" "email" {
  count     = var.email_endpoint != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.email_endpoint
}

# CloudWatch Alarm: High CPU Usage
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = var.enable_cpu_alarm ? 1 : 0
  alarm_name          = "${var.resource_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# CloudWatch Alarm: High Memory Usage
resource "aws_cloudwatch_metric_alarm" "high_memory" {
  count               = var.enable_memory_alarm ? 1 : 0
  alarm_name          = "${var.resource_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

# CloudWatch Alarm: Service Down
resource "aws_cloudwatch_metric_alarm" "service_down" {
  count               = var.enable_health_alarm ? 1 : 0
  alarm_name          = "${var.resource_name}-service-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors service availability"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = var.target_group_arn
    LoadBalancer = var.load_balancer_arn
  }

  tags = var.tags
}

# CloudWatch Alarm: Database Connection Failures
resource "aws_cloudwatch_metric_alarm" "db_connections" {
  count               = var.enable_db_alarm ? 1 : 0
  alarm_name          = "${var.resource_name}-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.db_connection_threshold
  alarm_description   = "This metric monitors database connection count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }

  tags = var.tags
}

