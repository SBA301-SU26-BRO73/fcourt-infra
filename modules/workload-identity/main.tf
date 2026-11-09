data "aws_caller_identity" "current" {

}
data "aws_partition" "current" {

}
data "aws_region" "current" {

}
locals {
  tags = merge(var.tags, {
    Project = "fcourt", Env = var.env, ManagedBy = "terraform"
  })
}
resource "aws_iam_role" "load_balancer_controller" {

  name = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
        }, Action = ["sts:AssumeRole", "sts:TagSession"], Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }, ArnEquals = {
          "aws:SourceArn" = var.cluster_arn
        }
      }
    }]
  })
  tags = local.tags

}
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Official AWS Load Balancer Controller policy; source URL in README"
  policy      = file("${path.module}/lbc-iam-policy.json")
  tags        = local.tags
}
resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}
resource "aws_eks_pod_identity_association" "load_balancer_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.load_balancer_controller.arn
  tags            = local.tags
  depends_on      = [aws_iam_role_policy_attachment.load_balancer_controller]
}
resource "aws_iam_role" "external_secrets" {

  name = "${var.cluster_name}-external-secrets"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
        }, Action = ["sts:AssumeRole", "sts:TagSession"], Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }, ArnEquals = {
          "aws:SourceArn" = var.cluster_arn
        }
      }
    }]
  })
  tags = local.tags

}
resource "aws_iam_role_policy" "external_secrets" {

  name = "${var.cluster_name}-external-secrets-read"
  role = aws_iam_role.external_secrets.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecretVersionIds"], Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:/fcourt/${var.env}/*"
      },
    ]
  })

}
resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
  tags            = local.tags
}
