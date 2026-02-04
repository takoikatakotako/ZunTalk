# =============================================================================
# ECR Repositories
# =============================================================================

# バックエンドAPI用のECRリポジトリ
module "ecr_backend" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
  max_image_count      = 20
  allowed_account_ids  = local.ecr_allowed_account_ids

  tags = {
    Name = "zuntalk-backend"
  }
}

# Slack通知用Lambda用のECRリポジトリ
module "ecr_slack_notifier" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-slack-notifier"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
  max_image_count      = 5
  allowed_account_ids  = local.ecr_allowed_account_ids

  tags = {
    Name = "zuntalk-slack-notifier"
  }
}

# =============================================================================
# S3 Bucket for Resources
# VOICEVOXフレームワーク、Open JTalk辞書、音声モデルなどの共有リソース
# =============================================================================

module "s3_resources" {
  source = "../../modules/s3"

  bucket_name                        = "zuntalk-resources"
  enable_versioning                  = true
  enable_lifecycle_rule              = true
  noncurrent_version_expiration_days = 90

  tags = {
    Name = "zuntalk-resources"
  }
}
