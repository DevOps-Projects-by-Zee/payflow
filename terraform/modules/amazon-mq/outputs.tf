output "broker_id" {
  description = "ID of the Amazon MQ broker"
  value       = aws_mq_broker.main.id
}

output "broker_arn" {
  description = "ARN of the Amazon MQ broker"
  value       = aws_mq_broker.main.arn
}

output "broker_name" {
  description = "Name of the Amazon MQ broker"
  value       = aws_mq_broker.main.broker_name
}

output "amqp_endpoint" {
  description = "AMQP endpoint URL (for RabbitMQ)"
  value       = aws_mq_broker.main.amqp_endpoints[0]
  sensitive   = true
}

output "amqp_ssl_endpoint" {
  description = "AMQP SSL endpoint URL"
  value       = aws_mq_broker.main.amqp_ssl_endpoints[0]
  sensitive   = true
}

output "connection_string_template" {
  description = "Connection string template (replace with actual endpoint)"
  value       = "amqps://${var.username}:PASSWORD@${replace(aws_mq_broker.main.amqp_ssl_endpoints[0], "amqps://", "")}/"
}

