data "aws_caller_identity" "current" {}

locals {
  # Trust policy shared by every Pod Identity role in this module.
  pod_identity_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnEquals    = { "aws:SourceArn" = var.cluster_arn }
      }
    }]
  })
}

# --- AWS Load Balancer Controller -------------------------------------------

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = local.pod_identity_assume_role_policy
  tags               = var.tags
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "Official AWS Load Balancer Controller policy (see README for the source)."
  policy      = file("${path.module}/lbc-iam-policy.json")
  tags        = var.tags
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
  tags            = var.tags
  depends_on      = [aws_iam_role_policy_attachment.load_balancer_controller]
}

# --- Associations for roles created elsewhere (for example notification-service)

resource "aws_eks_pod_identity_association" "extra" {
  for_each        = var.extra_associations
  cluster_name    = var.cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = each.value.role_arn
  tags            = var.tags
}
