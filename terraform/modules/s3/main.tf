resource "aws_s3_bucket" "default" {
  bucket = var.bucket_name

  tags = var.tags
}

# パブリックアクセスブロック設定
resource "aws_s3_bucket_public_access_block" "default" {
  bucket = aws_s3_bucket.default.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# バージョニング設定
resource "aws_s3_bucket_versioning" "default" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.default.id

  versioning_configuration {
    status = "Enabled"
  }
}

# サーバーサイド暗号化
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.default.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
  }
}

# ライフサイクルルール
resource "aws_s3_bucket_lifecycle_configuration" "default" {
  count  = var.enable_lifecycle_rule ? 1 : 0
  bucket = aws_s3_bucket.default.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}
