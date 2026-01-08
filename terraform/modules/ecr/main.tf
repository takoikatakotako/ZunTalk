resource "aws_ecr_repository" "default" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "default" {
  repository = aws_ecr_repository.default.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy for cross-account access
resource "aws_ecr_repository_policy" "default" {
  count      = length(var.allowed_account_ids) > 0 ? 1 : 0
  repository = aws_ecr_repository.default.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = [for account_id in var.allowed_account_ids : "arn:aws:iam::${account_id}:root"]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories"
        ]
      },
      {
        Sid    = "AllowCrossAccountLambda"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Condition = {
          ArnLike = {
            "aws:sourceArn" = [for account_id in var.allowed_account_ids : "arn:aws:lambda:*:${account_id}:function:*"]
          }
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
