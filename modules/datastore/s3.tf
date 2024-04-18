resource "aws_s3_bucket" "this" {
  bucket        = local.s3_bucket_name
  acl           = "private"
  force_destroy = var.force_destroy_s3_bucket
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = merge(
    var.standard_tags,
    {
      Metaflow = "true"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_policy     = true
  block_public_acls       = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_s3_intelligent_tiering ? 1 : 0
  bucket = aws_s3_bucket.this.id
  rule {
    # this rule configuration template is taken from AWS's official docs
    # https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-intelligent-tiering.html
    id     = "intelligent-tiering"
    status = "Enabled"
    filter {} # apply to all objects indiscriminately
    transition {
      days          = 0 # transition immediately
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}
