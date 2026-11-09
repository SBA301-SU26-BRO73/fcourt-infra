output "association_id" {

  description = "EKS Pod Identity association identifier."
  value       = aws_eks_pod_identity_association.service_account.association_id

}
