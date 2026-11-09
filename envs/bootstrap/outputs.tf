output "state_bucket_name" {
  description = "Bucket name to use in each environment backend.hcl."
  value       = aws_s3_bucket.state.id
}
output "state_bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.state.arn
}
