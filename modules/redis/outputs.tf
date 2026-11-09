output "primary_endpoint_address" {
  description = "Private Redis primary endpoint hostname."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}
output "port" {
  description = "Redis TLS port."
  value       = aws_elasticache_replication_group.this.port
}
