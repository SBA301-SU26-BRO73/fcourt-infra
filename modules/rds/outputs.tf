output "address" {
  description = "Private PostgreSQL endpoint hostname."
  value       = aws_db_instance.this.address
}
output "port" {
  description = "PostgreSQL port."
  value       = aws_db_instance.this.port
}
output "database" {
  description = "Initial database name   create service-specific databases as described in README."
  value       = aws_db_instance.this.db_name
}
output "master_secret_arn" {
  description = "Secrets Manager ARN for RDS-managed master credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
output "security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.this.id
}
