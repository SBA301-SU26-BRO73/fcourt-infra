locals {
  tags = merge(var.tags, {
    Project = "fcourt", ManagedBy = "terraform"
  })
}
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids
  tags       = local.tags
}
resource "aws_security_group" "this" {
  name        = "${var.name}-redis"
  description = "Redis from EKS nodes only"
  vpc_id      = var.vpc_id
  egress      = []
  tags = merge(local.tags, {
    Name = "${var.name}-redis"
  })
}
resource "aws_vpc_security_group_ingress_rule" "nodes" {
  security_group_id            = aws_security_group.this.id
  description                  = "Redis TLS from EKS nodes"
  referenced_security_group_id = var.node_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_elasticache_replication_group" "this" {

  replication_group_id       = var.name
  description                = "FCourt Redis cache"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.node_type
  port                       = 6379
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.this.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  num_cache_clusters         = var.multi_az ? 2 : 1
  automatic_failover_enabled = var.multi_az
  multi_az_enabled           = var.multi_az
  auto_minor_version_upgrade = true
  tags                       = local.tags

}
