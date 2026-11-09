output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}
output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}
output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}
output "cluster_certificate_authority_data" {
  description = "Base64 cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}
output "node_security_group_id" {
  description = "Managed node security group ID for data-layer ingress rules."
  value       = aws_security_group.nodes.id
}
output "node_role_arn" {
  description = "Managed node role ARN."
  value       = aws_iam_role.node.arn
}
output "ebs_csi_role_arn" {
  description = "Pod Identity role ARN for the EBS CSI add-on."
  value       = aws_iam_role.ebs_csi.arn
}
