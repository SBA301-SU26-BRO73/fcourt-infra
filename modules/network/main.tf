locals {
  # Derived from the VPC CIDR so subnets can never fall outside it.
  public_subnet_cidrs  = coalesce(var.public_subnet_cidrs, [for i in range(3) : cidrsubnet(var.cidr, 4, i)])
  private_subnet_cidrs = coalesce(var.private_subnet_cidrs, [for i in range(3) : cidrsubnet(var.cidr, 4, i + 3)])
}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
locals {
  nat_az_indexes = var.nodes_in_public_subnets ? [] : (var.single_nat_gateway ? [0] : [0, 1, 2])
}
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.name}-public-${count.index + 1}", "kubernetes.io/role/elb" = "1", "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = merge(var.tags, {
    Name = "${var.name}-private-${count.index + 1}", "kubernetes.io/role/internal-elb" = "1", "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}
resource "aws_eip" "nat" {
  count  = length(local.nat_az_indexes)
  domain = "vpc"
  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })
  depends_on = [aws_internet_gateway.this]
}
resource "aws_nat_gateway" "this" {
  count         = length(local.nat_az_indexes)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[local.nat_az_indexes[count.index]].id
  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })
  depends_on = [aws_internet_gateway.this]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-private-${count.index + 1}"
  })
}
resource "aws_route" "private_nat" {
  count                  = var.nodes_in_public_subnets ? 0 : 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags = merge(var.tags, {
    Name = "${var.name}-s3-endpoint"
  })
}
resource "aws_vpc_endpoint" "ecr_api" {
  count               = var.enable_ecr_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags = merge(var.tags, {
    Name = "${var.name}-ecr-api-endpoint"
  })
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = var.enable_ecr_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.endpoints[0].id]
  tags = merge(var.tags, {
    Name = "${var.name}-ecr-dkr-endpoint"
  })
}
resource "aws_security_group" "endpoints" {
  count       = var.enable_ecr_endpoints ? 1 : 0
  name        = "${var.name}-endpoints"
  description = "HTTPS access to VPC interface endpoints"
  vpc_id      = aws_vpc.this.id
  tags = merge(var.tags, {
    Name = "${var.name}-endpoints"
  })
}
resource "aws_vpc_security_group_ingress_rule" "endpoint_https" {
  count             = var.enable_ecr_endpoints ? 1 : 0
  security_group_id = aws_security_group.endpoints[0].id
  description       = "HTTPS from VPC"
  cidr_ipv4         = var.cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "endpoint_all" {
  count             = var.enable_ecr_endpoints ? 1 : 0
  security_group_id = aws_security_group.endpoints[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = 30
  tags              = var.tags
}
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-vpc-flow-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }, Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-vpc-flow-logs"
  role  = aws_iam_role.flow_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"], Resource = "*"
    }]
  })
}
resource "aws_flow_log" "this" {
  count           = var.enable_flow_logs ? 1 : 0
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  tags            = var.tags
}
