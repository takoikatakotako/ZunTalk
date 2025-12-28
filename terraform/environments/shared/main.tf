module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
  max_image_count      = 20
  allowed_account_ids  = var.ecr_allowed_account_ids

  tags = {
    Name = "zuntalk-backend"
  }
}
