# =============================================================================
# GitHub Actions OIDC Provider
# =============================================================================

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [var.github_oidc_thumbprint]

  tags = {
    Name = "github-actions-oidc-provider"
  }
}

# =============================================================================
# GitHub Actions IAM Role
# =============================================================================

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
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

resource "aws_iam_role" "github_actions" {
  name               = "zuntalk-prod-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "zuntalk-prod-github-actions"
  }
}

# =============================================================================
# Lambda Update Policy
# =============================================================================

data "aws_iam_policy_document" "github_actions_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction"
    ]
    resources = [
      module.lambda_backend.function_arn,
      module.lambda_slack_notifier.function_arn
    ]
  }

  # クロスアカウントECRイメージをLambdaで使用するために必要
  # LambdaサービスがGitHub Actionsロールの認証情報でECRにアクセスする
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_lambda" {
  name   = "LambdaUpdatePolicy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_lambda.json
}
