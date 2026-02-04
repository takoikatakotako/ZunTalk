# =============================================================================
# GitHub Actions IAM Role
# GitHub ActionsからAWSリソースにアクセスするためのIAMロール
# OIDC認証を使用してGitHub Actionsからのアクセスを許可
# =============================================================================

# Assume Role Policy Document
# GitHub ActionsのOIDCプロバイダーからのAssumeRoleを許可
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:takoikatakotako/ZunTalk:*"]
    }
  }
}

# GitHub Actions用IAMロール
resource "aws_iam_role" "github_actions" {
  name               = "zuntalk-shared-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "zuntalk-shared-github-actions"
  }
}

# =============================================================================
# ECR Push Policy
# GitHub ActionsからECRにDockerイメージをプッシュするための権限
# =============================================================================

data "aws_iam_policy_document" "github_actions_ecr" {
  # ECR認証トークン取得
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  # ECRへのイメージプッシュ・読み取り
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages"
    ]
    resources = [
      module.ecr_backend.repository_arn,
      module.ecr_slack_notifier.repository_arn
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name   = "ECRPushPolicy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

# =============================================================================
# S3 Read Policy
# GitHub ActionsからS3リソースバケットを読み取るための権限
# =============================================================================

data "aws_iam_policy_document" "github_actions_s3" {
  # S3リソースの読み取り
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      module.s3_resources.bucket_arn,
      "${module.s3_resources.bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "github_actions_s3" {
  name   = "S3ReadPolicy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_s3.json
}
