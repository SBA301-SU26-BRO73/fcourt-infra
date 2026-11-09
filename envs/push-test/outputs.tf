output "platform_application_arn" {

  description = "SNS FCM platform application ARN."
  value       = module.push.platform_application_arn

}

output "note" {

  description = "Reminder about this standalone SNS test."
  value       = "This root module creates SNS push resources without EKS. Its local Terraform state contains the Firebase key and must remain on this machine."

}
