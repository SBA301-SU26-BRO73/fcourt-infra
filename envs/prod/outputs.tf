output "platform_application_arn" {
  description = "SNS FCM platform application ARN."
  value       = module.push.platform_application_arn
}

output "notification_service_role_arn" {
  description = "IAM role ARN for notification-service."
  value       = module.push.notification_service_role_arn
}

output "reminder_queue_arn" {
  description = "Reminder queue ARN when enabled."
  value       = module.push.reminder_queue_arn
}
