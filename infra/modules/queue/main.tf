# Queue Module
# Placeholder for future queue/message broker resources
# This module can be extended to support SQS, RabbitMQ, Kafka, etc.

# Example: AWS SQS queue (commented out for now)
# resource "aws_sqs_queue" "this" {
#   name = "${var.name}-${var.environment}"
#   tags = var.tags
# }

# Example: Kubernetes-based queue (e.g., RabbitMQ)
# module "rabbitmq" {
#   source = "../app"
#   ...
# }

output "queue_name" {
  description = "Name of the queue (placeholder)"
  value       = var.name
}
