data "aws_eks_cluster" "existing" {
  name = var.cluster_name
}

resource "aws_eks_pod_identity_association" "service_account" {
  cluster_name    = data.aws_eks_cluster.existing.name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = var.role_arn
  tags            = var.tags
}
