data "aws_region" "current" {}
data "aws_partition" "current" {

}
locals {
  tags = merge(var.tags, {
    Project = "fcourt", ManagedBy = "terraform"
  })
}
resource "aws_cloudwatch_log_group" "cluster" {
  count             = length(var.cluster_log_types) > 0 ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.tags
}
resource "aws_kms_key" "cluster" {
  count = var.enable_secrets_encryption ? 1 : 0

  description             = "EKS secrets encryption for ${var.cluster_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      {
        Sid = "Enable IAM User Permissions", Effect = "Allow", Principal = {
          AWS     = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }, Action = "kms:*", Resource = "*"
      },
      {
        Sid = "Allow EKS to use key", Effect = "Allow", Principal = {
          Service = "eks.amazonaws.com"
          }, Action = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant"], Resource = "*", Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      }
    ]
  })
  tags = local.tags

}
data "aws_caller_identity" "current" {

}
resource "aws_iam_role" "cluster" {

  name = "${var.cluster_name}-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "eks.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags

}
resource "aws_iam_role_policy_attachment" "cluster" {
  for_each   = toset(["arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy", "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"])
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-control-plane"
  description = "EKS control plane security group"
  vpc_id      = var.vpc_id
  egress      = []
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-control-plane"
  })
}
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "EKS managed worker nodes"
  vpc_id      = var.vpc_id
  egress      = []
  tags = merge(local.tags, {
    Name = "${var.cluster_name}-nodes", "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}
resource "aws_vpc_security_group_ingress_rule" "node_self" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Node-to-node traffic"
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
}
resource "aws_vpc_security_group_ingress_rule" "control_to_node" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Control plane to kubelet"
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 1025
  to_port                      = 65535
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "node_all" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_ingress_rule" "node_to_control_plane" {
  security_group_id            = aws_security_group.cluster.id
  description                  = "Kubernetes API from EKS nodes"
  referenced_security_group_id = aws_security_group.nodes.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "control_plane_all" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_iam_role" "node" {

  name = "${var.cluster_name}-nodes"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "ec2.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags

}
resource "aws_iam_role_policy_attachment" "node" {
  for_each   = toset(["arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy", "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}
resource "aws_iam_role" "ebs_csi" {

  name = "${var.cluster_name}-ebs-csi"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "pods.eks.amazonaws.com"
        }, Action = ["sts:AssumeRole", "sts:TagSession"], Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }, ArnEquals = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
        }
      }
    }]
  })
  tags = local.tags

}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_eks_cluster" "this" {

  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.cluster_public_access_cidrs
  }
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  dynamic "encryption_config" {
    for_each = var.enable_secrets_encryption ? [1] : []
    content {
      provider {
        key_arn = aws_kms_key.cluster[0].arn
      }
      resources = ["secrets"]
    }
  }
  enabled_cluster_log_types = var.cluster_log_types
  depends_on                = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
  tags                      = local.tags

}
resource "aws_eks_access_entry" "admin" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "admin" {
  for_each      = aws_eks_access_entry.admin
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}
resource "aws_eks_node_group" "this" {

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-workers"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.nodes_in_public_subnets ? var.public_subnet_ids : var.private_subnet_ids
  instance_types  = var.instance_types
  capacity_type   = var.capacity_type
  scaling_config {
    min_size     = var.min_size
    desired_size = var.desired_size
    max_size     = var.max_size
  }
  update_config {
    max_unavailable = 1
  }
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }
  depends_on = [aws_eks_access_policy_association.admin, aws_iam_role_policy_attachment.node]
  tags       = local.tags

}
resource "aws_launch_template" "nodes" {

  name_prefix            = "${var.cluster_name}-node-"
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.nodes_in_public_subnets
    security_groups             = [aws_security_group.nodes.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${var.cluster_name}-worker"
    })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }
  tag_specifications {
    resource_type = "network-interface"
    tags          = local.tags
  }
  tags = local.tags

}
resource "aws_eks_addon" "core" {

  for_each                    = toset(["vpc-cni", "coredns", "kube-proxy", "eks-pod-identity-agent", "aws-ebs-csi-driver"])
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = local.tags
  depends_on                  = [aws_eks_node_group.this]

}
resource "aws_eks_pod_identity_association" "ebs_csi" {

  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
  tags            = local.tags
  depends_on      = [aws_eks_addon.core, aws_iam_role_policy_attachment.ebs_csi]

}
