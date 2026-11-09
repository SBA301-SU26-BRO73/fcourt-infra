output "platform_application_arn" {
  description = "SNS FCM platform application ARN."
  value       = aws_sns_platform_application.push.arn
}

output "notification_service_role_arn" {
  description = "IAM role ARN for notification-service workload identity."
  value       = aws_iam_role.notification_service.arn
}

output "reminder_queue_arn" {
  description = "Reminder SQS queue ARN, when reminders are enabled."
  value       = var.enable_reminder ? aws_sqs_queue.reminder[0].arn : null
}

output "reminder_dlq_arn" {
  description = "Reminder dead-letter queue ARN, when reminders are enabled."
  value       = var.enable_reminder ? aws_sqs_queue.reminder_dlq[0].arn : null
}

output "scheduler_group_name" {
  description = "EventBridge Scheduler group name, when reminders are enabled."
  value       = var.enable_reminder ? aws_scheduler_schedule_group.reminder[0].name : null
}
