output "platform_application_arn" {
  description = "SNS FCM platform application ARN."
  value       = aws_sns_platform_application.push.arn
}

output "notification_service_role_arn" {
  description = "IAM role ARN for notification-service workload identity."
  value       = try(one(aws_iam_role.notification_service[*].arn), null)
}

output "reminder_queue_arn" {
  description = "Reminder SQS queue ARN, when reminders are enabled."
  value       = try(one(aws_sqs_queue.reminder[*].arn), null)
}

output "reminder_dlq_arn" {
  description = "Reminder dead-letter queue ARN, when reminders are enabled."
  value       = try(one(aws_sqs_queue.reminder_dlq[*].arn), null)
}

output "scheduler_group_name" {
  description = "EventBridge Scheduler group name, when reminders are enabled."
  value       = try(one(aws_scheduler_schedule_group.reminder[*].name), null)
}
