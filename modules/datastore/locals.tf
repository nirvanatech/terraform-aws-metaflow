locals {
  # Name of PostgresQL subnet group.
  pg_subnet_group_name = "${var.resource_prefix}main${var.resource_suffix}"

  # Name of the RDS security group
  rds_security_group_name = "${var.resource_prefix}rds-security-group${var.resource_suffix}"

  # Name of S3 bucket
  s3_bucket_name_prefix = "${var.resource_prefix}s3${var.resource_suffix}"
  s3_bucket_name        = var.randomize_s3_name ? "${local.s3_bucket_name_prefix}-${random_string.bucket_suffix.result}" : local.s3_bucket_name_prefix
}

resource "random_string" "bucket_suffix" {
  count   = var.randomize_s3_name ? 1 : 0
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}
