resource "aws_security_group" "this" {
  name        = "${var.name}-kafka"
  description = "Kafka TLS from EKS nodes only"
  vpc_id      = var.vpc_id
  egress      = []
  tags = merge(var.tags, {
    Name = "${var.name}-kafka"
  })
}
resource "aws_vpc_security_group_ingress_rule" "nodes" {
  security_group_id            = aws_security_group.this.id
  description                  = "Kafka TLS with IAM auth from EKS nodes"
  referenced_security_group_id = var.node_security_group_id
  from_port                    = 9098
  to_port                      = 9098
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.name
  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }
  # MSK Serverless always encrypts in transit (TLS), there is no setting for it.
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }
  tags = var.tags
}
