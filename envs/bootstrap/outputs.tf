output "state_bucket_name" {
  description = "Bucket name for the dev and prod S3 backends."
  value       = aws_s3_bucket.state.id
}
output "state_bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.state.arn
}
