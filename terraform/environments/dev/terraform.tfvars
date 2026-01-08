# =============================================================================
# Dev Environment Variables
# =============================================================================

slack_notifier_image_uri = "448049807848.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-slack-notifier:latest"

# GitHub Actions OIDC thumbprint
# AWSは2023年7月以降検証しなくなったが、Terraformの必須パラメータのため設定
github_oidc_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
