resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
  tags = merge(var.tags, {
    Name = "${var.name}-db"
  })
}
resource "aws_security_group" "this" {
  name        = "${var.name}-postgres"
  description = "PostgreSQL access from EKS worker nodes only"
  vpc_id      = var.vpc_id
  egress      = []
  tags = merge(var.tags, {
    Name = "${var.name}-postgres"
  })
}
resource "aws_vpc_security_group_ingress_rule" "nodes" {
  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from EKS nodes"
  referenced_security_group_id = var.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_db_instance" "this" {
  identifier                  = var.name
  engine                      = "postgres"
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  max_allocated_storage       = max(var.allocated_storage, 100)
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "fcourt"
  username                    = "fcourt_admin"
  manage_master_user_password = true
  port                        = 5432
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.this.id]
  publicly_accessible         = false
  multi_az                    = var.multi_az
  backup_retention_period     = var.env == "prod" ? 7 : 1
  deletion_protection         = var.env == "prod"
  skip_final_snapshot         = var.env != "prod"
  final_snapshot_identifier   = var.env == "prod" ? "${var.name}-final" : null
  auto_minor_version_upgrade  = true
  copy_tags_to_snapshot       = true
  tags = merge(var.tags, {
    Name = var.name
  })
}
