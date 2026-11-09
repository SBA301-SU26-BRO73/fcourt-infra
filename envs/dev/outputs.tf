output "platform_application_arn" {
  description = "SNS FCM platform application ARN."
  value       = module.push.platform_application_arn
}

output "notification_service_role_arn" {
  description = "IAM role ARN assigned to notification-service."
  value       = module.push.notification_service_role_arn
}

output "reminder_queue_arn" {
  description = "Reminder queue ARN if reminders are enabled."
  value       = module.push.reminder_queue_arn
}

output "reminder_dlq_arn" {
  description = "Reminder dead-letter queue ARN if reminders are enabled."
  value       = module.push.reminder_dlq_arn
}
