output "cluster_arn" {
  description = "MSK Serverless cluster ARN."
  value       = aws_msk_serverless_cluster.this.arn
}
output "bootstrap_brokers_sasl_iam" {
  description = "TLS bootstrap brokers for SASL/IAM clients."
  value       = aws_msk_serverless_cluster.this.bootstrap_brokers_sasl_iam
}
