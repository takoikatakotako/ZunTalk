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
