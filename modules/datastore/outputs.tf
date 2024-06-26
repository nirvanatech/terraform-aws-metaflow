output "METAFLOW_DATATOOLS_S3ROOT" {
  value       = "s3://${aws_s3_bucket.this.bucket}/data"
  description = "Amazon S3 URL for Metaflow DataTools"
}

output "METAFLOW_DATASTORE_SYSROOT_S3" {
  value       = "s3://${aws_s3_bucket.this.bucket}/metaflow"
  description = "Amazon S3 URL for Metaflow DataStore"
}

output "database_name" {
  value       = var.db_name
  description = "The database name"
}

output "database_password" {
  value       = random_password.this.result
  description = "The database password"
}

output "database_username" {
  value       = var.db_username
  description = "The database username"
}

output "database_sg_id" {
  value       = aws_security_group.rds_security_group.id
  description = "The RDS security group ID to attach new rules"
}

output "datastore_s3_bucket_kms_key_arn" {
  value       = aws_kms_key.s3.arn
  description = "The ARN of the KMS key used to encrypt the Metaflow datastore S3 bucket"
}

output "rds_master_instance_endpoint" {
  value       = local.use_aurora ? aws_rds_cluster.this[0].endpoint : aws_db_instance.this[0].endpoint
  description = "The database connection endpoint in address:port format"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.this.arn
  description = "The ARN of the bucket we'll be using as blob storage"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "The name of the bucket we'll be using as blob storage"
}
