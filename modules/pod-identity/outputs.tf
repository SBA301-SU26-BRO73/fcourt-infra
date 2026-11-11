output "load_balancer_controller_role_arn" {
  description = "Pod Identity role ARN for the AWS Load Balancer Controller."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "extra_association_ids" {
  description = "Pod Identity association IDs for extra_associations, keyed by name."
  value       = { for k, a in aws_eks_pod_identity_association.extra : k => a.association_id }
}
